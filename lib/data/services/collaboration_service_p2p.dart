import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/collaboration_transport.dart';
import 'package:whisk/data/services/local_collaboration_transport.dart';
import 'package:whisk/domain/models/collaboration_file_entry.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/src/rust/api/collaboration.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';
import 'package:whisk/ui/features/workspace/widgets/log_viewer_dialog.dart';

class CollaborationServiceP2p
    implements CollaborationService, CollaborationTransportClient {
  CollaborationServiceP2p({
    String? peerId,
    String? peerName,
    Color? peerColor,
    CollaborationTransport? transport,
  }) : peerId = peerId ?? _createPeerId(),
       peerName = peerName ?? _defaultPeerName(),
       peerColor = peerColor ?? _palette[_random.nextInt(_palette.length)],
       _transport = transport ?? LocalCollaborationTransport(),
       _useRustEngine = true;

  @visibleForTesting
  CollaborationServiceP2p.localOnly({
    String? peerId,
    String? peerName,
    Color? peerColor,
    CollaborationTransport? transport,
  }) : peerId = peerId ?? _createPeerId(),
       peerName = peerName ?? _defaultPeerName(),
       peerColor = peerColor ?? _palette[_random.nextInt(_palette.length)],
       _transport = transport ?? LocalCollaborationTransport(),
       _useRustEngine = false;

  static final _random = Random();
  static const _palette = [
    Colors.purpleAccent,
    Colors.lightGreenAccent,
    Colors.orangeAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
  ];

  static String _defaultPeerName() {
    if (Platform.isWindows) {
      final user = Platform.environment['USERNAME'];
      if (user != null && user.isNotEmpty) return user;
    } else {
      final user = Platform.environment['USER'];
      if (user != null && user.isNotEmpty) return user;
    }
    return 'User';
  }

  final _peerController = StreamController<List<CollaborationPeer>>.broadcast();
  final _fileController =
      StreamController<List<CollaborationFileEntry>>.broadcast();
  final _textController = StreamController<CollaborationTextUpdate>.broadcast();

  @override
  final String peerId;
  final String peerName;
  final Color peerColor;
  final CollaborationTransport _transport;
  final bool _useRustEngine;
  CollaborationEngine? _engine;
  String? _invite;
  String? _joinedInvite;
  final _remoteInvites = <String, String>{};
  final _irohPresence = <String, CollaborationPeer>{};
  final _remoteStateVectors = <String, Map<String, List<int>>>{};
  final _irohLastSeen = <String, DateTime>{};
  final _pendingSnapshotRequests = <String, Completer<String?>>{};
  Completer<List<CollaborationFileEntry>>? _pendingManifestRequest;
  List<CollaborationFileEntry> _workspaceFiles = const [];
  CollaborationPeer? _localPresence;
  List<CollaborationPeer> _localTransportPeers = const [];
  List<CollaborationPeer> _irohPeers = const [];
  Timer? _irohInboxTimer;
  DateTime? _lastPresenceHeartbeat;
  bool _isConnecting = false;
  var _connected = false;

  @override
  bool get canWriteLocalFiles => _joinedInvite == null;

  @override
  Stream<List<CollaborationPeer>> get peers => _peerController.stream;

  @override
  Stream<List<CollaborationFileEntry>> get remoteFiles =>
      _fileController.stream;

  @override
  Stream<CollaborationTextUpdate> get remoteTextUpdates =>
      _textController.stream;

  @override
  Future<void> connect(String workspaceId) async {
    if (_isConnecting || _connected) return;
    _isConnecting = true;
    try {
      if (_useRustEngine) {
        _engine = CollaborationEngine();
        _invite = await _engine!.startSession();
        _startIrohInboxPolling();
      }
      await _transport.connect(workspaceId: workspaceId, client: this);
      _connected = true;
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _broadcastGoodbye();
    await _transport.disconnect();
    _irohInboxTimer?.cancel();
    _irohInboxTimer = null;
    await _engine?.closeSession();
    _engine?.dispose();
    _engine = null;
    _invite = null;
    _joinedInvite = null;
    _remoteInvites.clear();
    _irohPresence.clear();
    _remoteStateVectors.clear();
    _irohLastSeen.clear();
    _workspaceFiles = const [];
    final pendingManifest = _pendingManifestRequest;
    if (pendingManifest != null && !pendingManifest.isCompleted) {
      pendingManifest.complete(const []);
    }
    _pendingManifestRequest = null;
    _localPresence = null;
    _lastPresenceHeartbeat = null;
    for (final completer in _pendingSnapshotRequests.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pendingSnapshotRequests.clear();
    _localTransportPeers = const [];
    _irohPeers = const [];
    _connected = false;
    _peerController.add([]);
  }

  @override
  Future<String> loadFileSnapshot(String filePath, String localContent) async {
    final engine = _engine;
    final snapshot = await _transport.loadFileSnapshot(filePath, localContent);
    if (engine == null) return snapshot;

    if (_joinedInvite != null) {
      engine.loadFileSnapshot(filePath: filePath, text: '');
      final remoteSnapshot = await _requestIrohSnapshot(filePath);
      if (remoteSnapshot != null) return remoteSnapshot;
    }

    engine.loadFileSnapshot(filePath: filePath, text: snapshot);
    return snapshot;
  }

  @override
  Future<String?> createInvite() async {
    if (!_useRustEngine) return null;
    final engine = _engine;
    if (engine == null) return null;
    if (_invite == null || _invite!.isEmpty) {
      _invite = await engine.startSession();
    }
    return _invite!.isEmpty ? null : _invite;
  }

  @override
  Future<bool> joinInvite(String invite) async {
    if (!_useRustEngine) return false;
    if (invite.trim().isEmpty) return false;
    _joinedInvite = invite.trim();
    final engine = _engine;
    if (engine == null) return false;
    return _sendHelloToInvite(engine: engine, invite: _joinedInvite!);
  }

  @override
  Future<List<CollaborationFileEntry>> requestRemoteFiles() async {
    final engine = _engine;
    final joinedInvite = _joinedInvite;
    if (engine == null || joinedInvite == null) return const [];
    final existing = _pendingManifestRequest;
    if (existing != null) return existing.future;

    final completer = Completer<List<CollaborationFileEntry>>();
    _pendingManifestRequest = completer;
    final sent = await engine.sendBytesToInvite(
      invite: joinedInvite,
      payload: _encodeIrohEnvelope(type: 'manifest_request', peerId: peerId),
    );
    if (!sent && !completer.isCompleted) {
      completer.complete(const []);
    }

    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      return const [];
    } finally {
      if (identical(_pendingManifestRequest, completer)) {
        _pendingManifestRequest = null;
      }
    }
  }

  @override
  void updateWorkspaceFiles(List<CollaborationFileEntry> files) {
    _workspaceFiles = List.unmodifiable(files);
  }

  Future<bool> _sendHelloToInvite({
    required CollaborationEngine engine,
    required String invite,
  }) async {
    final localInvite = await createInvite();
    if (localInvite == null) return false;
    return engine.sendBytesToInvite(
      invite: invite,
      payload: _encodeIrohEnvelope(
        type: 'hello',
        peerId: peerId,
        invite: localInvite,
      ),
    );
  }

  @override
  void updateLocalCursor(
    String filePath,
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  }) {
    final peer = CollaborationPeer(
      id: peerId,
      name: peerName,
      color: peerColor,
      filePath: filePath,
      cursorOffset: offset,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
    );
    _localPresence = peer;
    _transport.updatePresence(peer);
    _broadcastPresence(peer);
  }

  @override
  void broadcastTextChange(CollaborationTextUpdate update) {
    if (update.peerId != peerId) return;
    try {
      _engine?.applyLocalEdit(
        filePath: update.filePath,
        op: RustTextOperation(
          offset: update.operation.offset,
          deletedLength: update.operation.deletedText.length,
          insertedText: update.operation.insertedText,
        ),
      );
    } catch (_) {}
    _broadcastCrdtUpdate(update.filePath, operation: update.operation);
    _transport.broadcastTextUpdate(update);
  }

  @override
  void receiveTextUpdate(CollaborationTextUpdate update) {
    if (update.peerId == peerId) return;
    try {
      _engine?.applyLocalEdit(
        filePath: update.filePath,
        op: RustTextOperation(
          offset: update.operation.offset,
          deletedLength: update.operation.deletedText.length,
          insertedText: update.operation.insertedText,
        ),
      );
    } catch (_) {}
    _textController.add(update);
  }

  @override
  void publishPeers(List<CollaborationPeer> peers) {
    _localTransportPeers = [
      for (final peer in peers)
        if (peer.id != peerId) peer,
    ];
    _publishCombinedPeers();
  }

  static String _createPeerId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 32);
    return 'peer-$micros-$salt';
  }

  void _broadcastCrdtUpdate(
    String filePath, {
    EditorTextOperation? operation,
  }) {
    final engine = _engine;
    if (engine == null) return;

    for (final target in _activeRemoteTargets()) {
      unawaited(
        _sendCrdtUpdateToTarget(
          engine: engine,
          filePath: filePath,
          target: target,
          operation: operation,
        ),
      );
    }
  }

  Future<void> _sendCrdtUpdateToTarget({
    required CollaborationEngine engine,
    required String filePath,
    required ({String? peerId, String invite}) target,
    EditorTextOperation? operation,
  }) async {
    final remoteStateVector = _stateVectorFor(
      peerId: target.peerId ?? target.invite,
      filePath: filePath,
    );
    final update = engine.encodeUpdateSince(
      filePath: filePath,
      stateVector: remoteStateVector,
    );
    if (update.isEmpty) return;

    final localStateVector = engine.encodeStateVector(filePath: filePath);
    final sent = await engine.sendBytesToInvite(
      invite: target.invite,
      payload: _encodeIrohEnvelope(
        type: 'crdt_update',
        peerId: peerId,
        filePath: filePath,
        update: update,
        stateVector: localStateVector,
        operation: operation,
      ),
    );
    if (!sent) return;
    _setStateVectorFor(
      peerId: target.peerId ?? target.invite,
      filePath: filePath,
      stateVector: localStateVector,
    );
  }

  void _startIrohInboxPolling() {
    _irohInboxTimer?.cancel();
    _irohInboxTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _drainIrohInbox();
      _sendPresenceHeartbeat();
      _removeStaleIrohPeers();
    });
  }

  void _drainIrohInbox() {
    final engine = _engine;
    if (engine == null) return;

    for (final payload in engine.drainReceivedBytes()) {
      final envelope = _decodeIrohEnvelope(payload);
      if (envelope == null) continue;
      if (envelope.type == 'hello') {
        _handleIrohHello(envelope);
        continue;
      }
      if (envelope.type == 'presence') {
        _handleIrohPresence(envelope);
        continue;
      }
      if (envelope.type == 'goodbye') {
        _handleIrohGoodbye(envelope);
        continue;
      }
      if (envelope.type == 'manifest_request') {
        _handleManifestRequest(envelope);
        continue;
      }
      if (envelope.type == 'manifest_response') {
        _handleManifestResponse(envelope);
        continue;
      }
      if (envelope.type == 'snapshot_request') {
        _handleSnapshotRequest(envelope);
        continue;
      }
      if (envelope.type == 'snapshot_response') {
        _handleSnapshotResponse(engine, envelope);
        continue;
      }
      if (envelope.type != 'crdt_update') continue;
      if (envelope.filePath == null || envelope.update == null) continue;
      _markIrohPeerSeen(envelope.peerId);

      String oldText;
      try {
        oldText = engine.getText(filePath: envelope.filePath!);
      } catch (_) {
        continue;
      }
      final applied = engine.applyRemoteUpdate(
        filePath: envelope.filePath!,
        update: envelope.update!,
      );
      if (!applied) continue;
      final String newText;
      try {
        newText = engine.getText(filePath: envelope.filePath!);
      } catch (_) {
        continue;
      }
      if (envelope.peerId != null && envelope.stateVector != null) {
        _setStateVectorFor(
          peerId: envelope.peerId!,
          filePath: envelope.filePath!,
          stateVector: envelope.stateVector!,
        );
      }
      final operation =
          _operationFromDiff(oldText, newText) ??
          _operationFromEnvelope(oldText, newText, envelope.operation);
      if (operation == null) continue;
      _textController.add(
        CollaborationTextUpdate(
          peerId: envelope.peerId ?? 'iroh-remote',
          filePath: envelope.filePath!,
          operation: operation,
        ),
      );
    }
  }

  List<int> _encodeIrohEnvelope({
    required String type,
    String? peerId,
    String? invite,
    String? filePath,
    List<int>? update,
    List<int>? stateVector,
    CollaborationPeer? peer,
    List<CollaborationFileEntry>? files,
    EditorTextOperation? operation,
  }) {
    final payload = <String, Object?>{'type': type};
    if (peerId != null) payload['peerId'] = peerId;
    if (invite != null) payload['invite'] = invite;
    if (filePath != null) payload['filePath'] = filePath;
    if (update != null) payload['update'] = base64Encode(update);
    if (stateVector != null) {
      payload['stateVector'] = base64Encode(stateVector);
    }
    if (peer != null) {
      payload['peer'] = {
        'id': peer.id,
        'name': peer.name,
        'color': peer.color.toARGB32(),
        'filePath': peer.filePath,
        'cursorOffset': peer.cursorOffset,
        'selectionStart': peer.selectionStart,
        'selectionEnd': peer.selectionEnd,
      };
    }
    if (files != null) {
      payload['files'] = [
        for (final file in files)
          {'path': file.path, 'name': file.name, 'extension': file.extension},
      ];
    }
    if (operation != null) {
      payload['operation'] = {
        'offset': operation.offset,
        'deletedText': operation.deletedText,
        'insertedText': operation.insertedText,
      };
    }
    return utf8.encode(jsonEncode(payload));
  }

  _IrohEnvelope? _decodeIrohEnvelope(Uint8List payload) {
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map<String, Object?>) return null;
      final type = decoded['type'];
      if (type is! String) return null;
      final peerId = decoded['peerId'];
      final invite = decoded['invite'];
      final filePath = decoded['filePath'];
      final update = decoded['update'];
      final stateVector = decoded['stateVector'];
      final peer = decoded['peer'];
      final files = decoded['files'];
      final operation = decoded['operation'];
      return _IrohEnvelope(
        type: type,
        peerId: peerId is String ? peerId : null,
        invite: invite is String ? invite : null,
        filePath: filePath is String ? filePath : null,
        update: update is String ? base64Decode(update) : null,
        stateVector: stateVector is String ? base64Decode(stateVector) : null,
        peer: peer is Map<String, Object?> ? _decodePeer(peer) : null,
        files: files is List<Object?> ? _decodeFiles(files) : null,
        operation: operation is Map<String, Object?>
            ? _decodeOperation(operation)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  void _handleIrohHello(_IrohEnvelope envelope) {
    final remotePeerId = envelope.peerId;
    final invite = envelope.invite;
    if (remotePeerId == null || invite == null) return;
    if (remotePeerId == peerId) return;
    LogBuffer.writeln(LogCategory.collab,
        'Peer joined: ${_shortPeerId(remotePeerId)}');
    final isNewPeer = !_remoteInvites.containsKey(remotePeerId);
    _remoteInvites[remotePeerId] = invite;
    _markIrohPeerSeen(remotePeerId);
    final inviteStateVectors = _remoteStateVectors.remove(invite);
    if (inviteStateVectors != null) {
      _remoteStateVectors[remotePeerId] = inviteStateVectors;
    }
    _irohPresence.putIfAbsent(
      remotePeerId,
      () => CollaborationPeer(
        id: remotePeerId,
        name: 'Remote ${_shortPeerId(remotePeerId)}',
        color: Colors.lightBlueAccent,
        filePath: '',
        cursorOffset: 0,
      ),
    );
    _rebuildIrohPeers();
    _publishCombinedPeers();
    if (isNewPeer) {
      final engine = _engine;
      if (engine != null) {
        unawaited(_sendHelloToInvite(engine: engine, invite: invite));
      }
    }
    final localPresence = _localPresence;
    if (localPresence != null) {
      _broadcastPresence(localPresence);
    }
  }

  void _handleIrohPresence(_IrohEnvelope envelope) {
    final peer = envelope.peer;
    if (peer == null || peer.id == peerId) return;
    _markIrohPeerSeen(peer.id);
    _irohPresence[peer.id] = peer;
    _rebuildIrohPeers();
    _publishCombinedPeers();
  }

  Future<void> _broadcastGoodbye() async {
    final engine = _engine;
    if (engine == null) return;
    final payload = _encodeIrohEnvelope(type: 'goodbye', peerId: peerId);
    await Future.wait([
      for (final target in _activeRemoteTargets())
        engine.sendBytesToInvite(invite: target.invite, payload: payload),
    ]).timeout(const Duration(milliseconds: 800), onTimeout: () => const []);
  }

  void _handleIrohGoodbye(_IrohEnvelope envelope) {
    final remotePeerId = envelope.peerId;
    if (remotePeerId == null || remotePeerId == peerId) return;
    LogBuffer.writeln(LogCategory.collab,
        '[collab] Peer left: ${_shortPeerId(remotePeerId)}');
    _remoteInvites.remove(remotePeerId);
    _irohPresence.remove(remotePeerId);
    _remoteStateVectors.remove(remotePeerId);
    _irohLastSeen.remove(remotePeerId);
    _rebuildIrohPeers();
    _publishCombinedPeers();
  }

  void _handleManifestRequest(_IrohEnvelope envelope) {
    final engine = _engine;
    final remotePeerId = envelope.peerId;
    if (engine == null || remotePeerId == null) return;
    final invite = _remoteInvites[remotePeerId];
    if (invite == null) return;
    unawaited(
      engine.sendBytesToInvite(
        invite: invite,
        payload: _encodeIrohEnvelope(
          type: 'manifest_response',
          peerId: peerId,
          files: _workspaceFiles,
        ),
      ),
    );
  }

  void _handleManifestResponse(_IrohEnvelope envelope) {
    final files = envelope.files;
    if (files == null) return;
    _fileController.add(files);
    final pending = _pendingManifestRequest;
    if (pending != null && !pending.isCompleted) {
      pending.complete(files);
    }
  }

  Future<String?> _requestIrohSnapshot(String filePath) async {
    final engine = _engine;
    final joinedInvite = _joinedInvite;
    if (engine == null || joinedInvite == null) return null;

    final existing = _pendingSnapshotRequests[filePath];
    if (existing != null) return existing.future;

    final completer = Completer<String?>();
    _pendingSnapshotRequests[filePath] = completer;
    final sent = await engine.sendBytesToInvite(
      invite: joinedInvite,
      payload: _encodeIrohEnvelope(
        type: 'snapshot_request',
        peerId: peerId,
        filePath: filePath,
      ),
    );
    if (!sent && !completer.isCompleted) {
      completer.complete(null);
    }

    try {
      return await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      return null;
    } finally {
      _pendingSnapshotRequests.remove(filePath);
    }
  }

  void _handleSnapshotRequest(_IrohEnvelope envelope) {
    final engine = _engine;
    final remotePeerId = envelope.peerId;
    final filePath = envelope.filePath;
    if (engine == null || remotePeerId == null || filePath == null) return;
    final invite = _remoteInvites[remotePeerId];
    if (invite == null) return;

    unawaited(
      engine.sendBytesToInvite(
        invite: invite,
        payload: _encodeIrohEnvelope(
          type: 'snapshot_response',
          peerId: peerId,
          filePath: filePath,
          update: engine.encodeFullUpdate(filePath: filePath),
          stateVector: engine.encodeStateVector(filePath: filePath),
        ),
      ),
    );
  }

  void _handleSnapshotResponse(
    CollaborationEngine engine,
    _IrohEnvelope envelope,
  ) {
    final filePath = envelope.filePath;
    final update = envelope.update;
    if (filePath == null || update == null) return;
    final completer = _pendingSnapshotRequests[filePath];
    if (completer == null) return;
    if (!engine.applyRemoteUpdate(filePath: filePath, update: update)) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }
    if (envelope.peerId != null && envelope.stateVector != null) {
      _setStateVectorFor(
        peerId: envelope.peerId!,
        filePath: filePath,
        stateVector: envelope.stateVector!,
      );
    }
    final snapshot = engine.getText(filePath: filePath);
    if (!completer.isCompleted) {
      completer.complete(snapshot);
    }
  }

  void _broadcastPresence(CollaborationPeer peer) {
    final engine = _engine;
    if (engine == null) return;
    final payload = _encodeIrohEnvelope(type: 'presence', peer: peer);
    for (final invite in _activeRemoteInvites()) {
      unawaited(engine.sendBytesToInvite(invite: invite, payload: payload));
    }
  }

  void _sendPresenceHeartbeat() {
    final localPresence = _localPresence;
    if (localPresence == null) return;
    final now = DateTime.now();
    final previous = _lastPresenceHeartbeat;
    if (previous != null && now.difference(previous).inSeconds < 5) return;
    _lastPresenceHeartbeat = now;
    _broadcastPresence(localPresence);
  }

  void _markIrohPeerSeen(String? remotePeerId) {
    if (remotePeerId == null || remotePeerId == peerId) return;
    _irohLastSeen[remotePeerId] = DateTime.now();
  }

  void _removeStaleIrohPeers() {
    if (_irohLastSeen.isEmpty) return;
    final now = DateTime.now();
    final stalePeerIds = [
      for (final entry in _irohLastSeen.entries)
        if (now.difference(entry.value).inSeconds > 30) entry.key,
    ];
    if (stalePeerIds.isEmpty) return;
    for (final peerId in stalePeerIds) {
      LogBuffer.writeln(LogCategory.collab,
          '[collab] Peer timed out: ${_shortPeerId(peerId)}');
      _remoteInvites.remove(peerId);
      _irohPresence.remove(peerId);
      _remoteStateVectors.remove(peerId);
      _irohLastSeen.remove(peerId);
    }
    _rebuildIrohPeers();
    _publishCombinedPeers();
  }

  CollaborationPeer? _decodePeer(Map<String, Object?> value) {
    final id = value['id'];
    final name = value['name'];
    final color = value['color'];
    final filePath = value['filePath'];
    if (id is! String ||
        name is! String ||
        color is! int ||
        filePath is! String) {
      return null;
    }
    final cursorOffset = value['cursorOffset'];
    final selectionStart = value['selectionStart'];
    final selectionEnd = value['selectionEnd'];
    return CollaborationPeer(
      id: id,
      name: name,
      color: Color(color),
      filePath: filePath,
      cursorOffset: cursorOffset is int ? cursorOffset : null,
      selectionStart: selectionStart is int ? selectionStart : null,
      selectionEnd: selectionEnd is int ? selectionEnd : null,
    );
  }

  List<CollaborationFileEntry> _decodeFiles(List<Object?> values) {
    final files = <CollaborationFileEntry>[];
    for (final value in values) {
      if (value is! Map<String, Object?>) continue;
      final path = value['path'];
      final name = value['name'];
      final extension = value['extension'];
      if (path is! String || name is! String || extension is! String) continue;
      files.add(
        CollaborationFileEntry(path: path, name: name, extension: extension),
      );
    }
    return List.unmodifiable(files);
  }

  void _rebuildIrohPeers() {
    _irohPeers = List.unmodifiable(_irohPresence.values);
  }

  Iterable<String> _activeRemoteInvites() sync* {
    final seen = <String>{};
    for (final invite in _remoteInvites.values) {
      if (seen.add(invite)) yield invite;
    }
    final joinedInvite = _joinedInvite;
    if (joinedInvite != null && seen.add(joinedInvite)) yield joinedInvite;
  }

  Iterable<({String? peerId, String invite})> _activeRemoteTargets() sync* {
    final seen = <String>{};
    for (final entry in _remoteInvites.entries) {
      if (seen.add(entry.value)) {
        yield (peerId: entry.key, invite: entry.value);
      }
    }
    final joinedInvite = _joinedInvite;
    if (joinedInvite != null && seen.add(joinedInvite)) {
      yield (peerId: null, invite: joinedInvite);
    }
  }

  List<int> _stateVectorFor({
    required String peerId,
    required String filePath,
  }) {
    return _remoteStateVectors[peerId]?[filePath] ?? const <int>[];
  }

  void _setStateVectorFor({
    required String peerId,
    required String filePath,
    required List<int> stateVector,
  }) {
    _remoteStateVectors.putIfAbsent(
      peerId,
      () => <String, List<int>>{},
    )[filePath] = List.unmodifiable(
      stateVector,
    );
  }

  void _publishCombinedPeers() {
    final seen = <String>{};
    final combined = <CollaborationPeer>[];
    for (final peer in [..._localTransportPeers, ..._irohPeers]) {
      if (!seen.add(peer.id)) continue;
      combined.add(peer);
    }
    _peerController.add(List.unmodifiable(combined));
  }

  String _shortPeerId(String value) {
    return value.substring(0, value.length < 8 ? value.length : 8);
  }

  EditorTextOperation? _operationFromDiff(String oldText, String newText) {
    if (oldText == newText) return null;

    var prefix = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLength &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    return EditorTextOperation(
      offset: prefix,
      deletedText: oldText.substring(prefix, oldSuffix),
      insertedText: newText.substring(prefix, newSuffix),
    );
  }

  EditorTextOperation? _decodeOperation(Map<String, Object?> value) {
    final offset = value['offset'];
    final deletedText = value['deletedText'];
    final insertedText = value['insertedText'];
    if (offset is! int || deletedText is! String || insertedText is! String) {
      return null;
    }
    return EditorTextOperation(
      offset: offset,
      deletedText: deletedText,
      insertedText: insertedText,
    );
  }

  EditorTextOperation? _operationFromEnvelope(
    String oldText,
    String newText,
    EditorTextOperation? operation,
  ) {
    if (operation == null) return null;
    final start = operation.offset;
    if (start < 0 || start > oldText.length) return null;
    final end = start + operation.deletedText.length;
    if (end < start || end > oldText.length) return null;
    if (oldText.substring(start, end) != operation.deletedText) return null;
    final applied = oldText.replaceRange(
      start,
      end,
      operation.insertedText,
    );
    return applied == newText ? operation : null;
  }
}

class _IrohEnvelope {
  const _IrohEnvelope({
    required this.type,
    this.peerId,
    this.invite,
    this.filePath,
    this.update,
    this.stateVector,
    this.peer,
    this.files,
    this.operation,
  });

  final String type;
  final String? peerId;
  final String? invite;
  final String? filePath;
  final Uint8List? update;
  final Uint8List? stateVector;
  final CollaborationPeer? peer;
  final List<CollaborationFileEntry>? files;
  final EditorTextOperation? operation;
}
