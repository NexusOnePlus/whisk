import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';

class CollaborationServiceMock implements CollaborationService {
  final _peerController = StreamController<List<CollaborationPeer>>.broadcast();
  final _textController = StreamController<EditorTextOperation>.broadcast();

  List<CollaborationPeer> _currentPeers = [];

  @override
  Stream<List<CollaborationPeer>> get peers => _peerController.stream;

  @override
  Stream<EditorTextOperation> get remoteTextUpdates => _textController.stream;

  @override
  Future<void> connect(String workspaceId) async {
    // Simulate a peer joining after a delay
    _currentPeers = [
      const CollaborationPeer(
        id: 'peer-1',
        name: 'Remote Writer',
        color: Colors.purpleAccent,
        cursorOffset: 0,
      ),
    ];
    _peerController.add(_currentPeers);
  }

  @override
  Future<void> disconnect() async {
    _currentPeers = [];
    _peerController.add(_currentPeers);
  }

  @override
  void updateLocalCursor(int offset, {int? selectionStart, int? selectionEnd}) {
    // In a real implementation, this would send local state to peers
  }

  @override
  void broadcastTextChange(EditorTextOperation operation) {
    // In a real implementation, this would sync with Yjs
  }

  void simulateRemoteCursorMove(int offset) {
    _currentPeers = _currentPeers
        .map((p) => p.copyWith(cursorOffset: offset))
        .toList();
    _peerController.add(_currentPeers);
  }
}
