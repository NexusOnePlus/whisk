import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/src/rust/api/collaboration.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class CollaborationServiceP2p implements CollaborationService {
  CollaborationServiceP2p({String? peerId, String? peerName, Color? peerColor})
    : peerId = peerId ?? _createPeerId(),
      peerName = peerName ?? 'Local ${_nextPeerNumber()}',
      peerColor = peerColor ?? _palette[_random.nextInt(_palette.length)],
      _useRustEngine = true;

  @visibleForTesting
  CollaborationServiceP2p.localOnly({
    String? peerId,
    String? peerName,
    Color? peerColor,
  }) : peerId = peerId ?? _createPeerId(),
       peerName = peerName ?? 'Local ${_nextPeerNumber()}',
       peerColor = peerColor ?? _palette[_random.nextInt(_palette.length)],
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
  final bool _useRustEngine;
  CollaborationEngine? _engine;
  _LocalCollaborationRoom? _room;
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
        await _engine!.startSession();
      }
      _room = _LocalCollaborationHub.join(workspaceId, this);
      _connected = true;
      _room!.publishPeers();
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _room?.leave(peerId);
    _room = null;
    _engine?.dispose();
    _engine = null;
    _connected = false;
    _peerController.add([]);
  }

  @override
  Future<String> loadFileSnapshot(String filePath, String localContent) async {
    final engine = _engine;
    final room = _room;
    if (room == null) return localContent;

    final snapshot = room.loadSnapshot(filePath, localContent);
    engine?.loadFileSnapshot(filePath: filePath, text: snapshot);
    return snapshot;
  }

  @override
  void updateLocalCursor(
    String filePath,
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  }) {
    _room?.updatePresence(
      CollaborationPeer(
        id: peerId,
        name: peerName,
        color: peerColor,
        filePath: filePath,
        cursorOffset: offset,
        selectionStart: selectionStart,
        selectionEnd: selectionEnd,
      ),
    );
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
    _room?.broadcastTextUpdate(update);
  }

  void _receiveTextUpdate(CollaborationTextUpdate update) {
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

  void _publishPeers(List<CollaborationPeer> peers) {
    _peerController.add([
      for (final peer in peers)
        if (peer.id != peerId) peer,
    ]);
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
}

class _LocalCollaborationHub {
  static final _rooms = <String, _LocalCollaborationRoom>{};

  static _LocalCollaborationRoom join(
    String workspaceId,
    CollaborationServiceP2p service,
  ) {
    final room = _rooms.putIfAbsent(
      workspaceId,
      () => _LocalCollaborationRoom(workspaceId),
    );
    room.join(service);
    return room;
  }
}

class _LocalCollaborationRoom {
  _LocalCollaborationRoom(this.workspaceId);

  final String workspaceId;
  final _members = <String, CollaborationServiceP2p>{};
  final _presence = <String, CollaborationPeer>{};
  final _snapshots = <String, String>{};

  void join(CollaborationServiceP2p service) {
    _members[service.peerId] = service;
  }

  void leave(String peerId) {
    _members.remove(peerId);
    _presence.remove(peerId);
    publishPeers();
  }

  String loadSnapshot(String filePath, String localContent) {
    return _snapshots.putIfAbsent(filePath, () => localContent);
  }

  void updatePresence(CollaborationPeer peer) {
    _presence[peer.id] = peer;
    publishPeers();
  }

  void publishPeers() {
    final peers = _presence.values.toList(growable: false);
    for (final member in _members.values) {
      member._publishPeers(peers);
    }
  }

  void broadcastTextUpdate(CollaborationTextUpdate update) {
    _snapshots[update.filePath] = _applyOperation(
      _snapshots[update.filePath] ?? '',
      update.operation,
    );
    for (final member in _members.values) {
      if (member.peerId == update.peerId) continue;
      member._receiveTextUpdate(update);
    }
  }

  String _applyOperation(String text, EditorTextOperation operation) {
    final start = operation.offset.clamp(0, text.length);
    final end = (start + operation.deletedText.length).clamp(
      start,
      text.length,
    );
    return text.replaceRange(start, end, operation.insertedText);
  }
}
