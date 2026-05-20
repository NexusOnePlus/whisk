import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/collaboration_transport.dart';
import 'package:whisk/data/services/local_collaboration_transport.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/src/rust/api/collaboration.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class CollaborationServiceP2p
    implements CollaborationService, CollaborationTransportClient {
  CollaborationServiceP2p({
    String? peerId,
    String? peerName,
    Color? peerColor,
    CollaborationTransport? transport,
  }) : peerId = peerId ?? _createPeerId(),
       peerName = peerName ?? 'Local ${_nextPeerNumber()}',
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
       peerName = peerName ?? 'Local ${_nextPeerNumber()}',
       peerColor = peerColor ?? _palette[_random.nextInt(_palette.length)],
       _transport = transport ?? LocalCollaborationTransport(),
       _useRustEngine = false;

  static final _random = Random();
  static var _peerCounter = 0;
  static const _palette = [
    Colors.purpleAccent,
    Colors.lightGreenAccent,
    Colors.orangeAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
  ];

  final _peerController = StreamController<List<CollaborationPeer>>.broadcast();
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
  final _pendingSnapshotRequests = <String, Completer<String?>>{};
  List<CollaborationPeer> _localTransportPeers = const [];
  List<CollaborationPeer> _irohPeers = const [];
  Timer? _irohInboxTimer;
  bool _isConnecting = false;
  var _connected = false;

  @override
  Stream<List<CollaborationPeer>> get peers => _peerController.stream;

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
    _transport.updatePresence(peer);
    _broadcastPresence(peer);
  }

  @override
  void broadcastTextChange(CollaborationTextUpdate update) {
    if (update.peerId != peerId) return;
    _engine?.applyLocalEdit(
      filePath: update.filePath,
      op: RustTextOperation(
        offset: update.operation.offset,
        deletedLength: update.operation.deletedText.length,
        insertedText: update.operation.insertedText,
      ),
    );
    _broadcastCrdtUpdate(update.filePath);
    _transport.broadcastTextUpdate(update);
  }

  @override
  void receiveTextUpdate(CollaborationTextUpdate update) {
    if (update.peerId == peerId) return;
    _engine?.applyLocalEdit(
      filePath: update.filePath,
      op: RustTextOperation(
        offset: update.operation.offset,
        deletedLength: update.operation.deletedText.length,
        insertedText: update.operation.insertedText,
      ),
    );
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

  static int _nextPeerNumber() {
    _peerCounter += 1;
    return _peerCounter;
  }

  void _broadcastCrdtUpdate(String filePath) {
    final engine = _engine;
    if (engine == null) return;

    for (final target in _activeRemoteTargets()) {
      unawaited(
        _sendCrdtUpdateToTarget(
          engine: engine,
          filePath: filePath,
          target: target,
        ),
      );
    }
  }

  Future<void> _sendCrdtUpdateToTarget({
    required CollaborationEngine engine,
    required String filePath,
    required ({String? peerId, String invite}) target,
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

      final oldText = engine.getText(filePath: envelope.filePath!);
      if (!engine.applyRemoteUpdate(
        filePath: envelope.filePath!,
        update: envelope.update!,
      )) {
        continue;
      }
      final newText = engine.getText(filePath: envelope.filePath!);
      if (envelope.peerId != null && envelope.stateVector != null) {
        _setStateVectorFor(
          peerId: envelope.peerId!,
          filePath: envelope.filePath!,
          stateVector: envelope.stateVector!,
        );
      }
      final operation = _operationFromDiff(oldText, newText);
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
      return _IrohEnvelope(
        type: type,
        peerId: peerId is String ? peerId : null,
        invite: invite is String ? invite : null,
        filePath: filePath is String ? filePath : null,
        update: update is String ? base64Decode(update) : null,
        stateVector: stateVector is String ? base64Decode(stateVector) : null,
        peer: peer is Map<String, Object?> ? _decodePeer(peer) : null,
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
    final isNewPeer = !_remoteInvites.containsKey(remotePeerId);
    _remoteInvites[remotePeerId] = invite;
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
  }

  void _handleIrohPresence(_IrohEnvelope envelope) {
    final peer = envelope.peer;
    if (peer == null || peer.id == peerId) return;
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
    _remoteInvites.remove(remotePeerId);
    _irohPresence.remove(remotePeerId);
    _remoteStateVectors.remove(remotePeerId);
    _rebuildIrohPeers();
    _publishCombinedPeers();
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

  void _rebuildIrohPeers() {
    _irohPeers = List.unmodifiable(_irohPresence.values);
  }

  Iterable<String> _activeRemoteInvites() sync* {
    final seen = <String>{};
    final joinedInvite = _joinedInvite;
    if (joinedInvite != null && seen.add(joinedInvite)) yield joinedInvite;
    for (final invite in _remoteInvites.values) {
      if (seen.add(invite)) yield invite;
    }
  }

  Iterable<({String? peerId, String invite})> _activeRemoteTargets() sync* {
    final seen = <String>{};
    final joinedInvite = _joinedInvite;
    if (joinedInvite != null && seen.add(joinedInvite)) {
      yield (peerId: null, invite: joinedInvite);
    }
    for (final entry in _remoteInvites.entries) {
      if (seen.add(entry.value)) {
        yield (peerId: entry.key, invite: entry.value);
      }
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
  });

  final String type;
  final String? peerId;
  final String? invite;
  final String? filePath;
  final Uint8List? update;
  final Uint8List? stateVector;
  final CollaborationPeer? peer;
}
