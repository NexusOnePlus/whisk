import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/collaboration_transport.dart';
import 'package:whisk/data/services/local_collaboration_transport.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/src/rust/api/collaboration.dart';

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
      await _transport.connect(workspaceId: workspaceId, client: this);
      _connected = true;
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _transport.disconnect();
    _engine?.dispose();
    _engine = null;
    _connected = false;
    _peerController.add([]);
  }

  @override
  Future<String> loadFileSnapshot(String filePath, String localContent) async {
    final engine = _engine;
    final snapshot = await _transport.loadFileSnapshot(filePath, localContent);
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
    _transport.updatePresence(
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
