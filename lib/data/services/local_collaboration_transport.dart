import 'package:whisk/data/services/collaboration_transport.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

class LocalCollaborationTransport implements CollaborationTransport {
  _LocalCollaborationRoom? _room;
  CollaborationTransportClient? _client;

  @override
  Future<void> connect({
    required String workspaceId,
    required CollaborationTransportClient client,
  }) async {
    _client = client;
    _room = _LocalCollaborationHub.join(workspaceId, client);
    _room!.publishPeers();
  }

  @override
  Future<void> disconnect() async {
    final client = _client;
    if (client != null) {
      _room?.leave(client.peerId);
    }
    _client = null;
    _room = null;
  }

  @override
  Future<String> loadFileSnapshot(String filePath, String localContent) async {
    return _room?.loadSnapshot(filePath, localContent) ?? localContent;
  }

  @override
  void updatePresence(CollaborationPeer peer) {
    _room?.updatePresence(peer);
  }

  @override
  void broadcastTextUpdate(CollaborationTextUpdate update) {
    _room?.broadcastTextUpdate(update);
  }
}

class _LocalCollaborationHub {
  static final _rooms = <String, _LocalCollaborationRoom>{};

  static _LocalCollaborationRoom join(
    String workspaceId,
    CollaborationTransportClient client,
  ) {
    final room = _rooms.putIfAbsent(
      workspaceId,
      () => _LocalCollaborationRoom(workspaceId),
    );
    room.join(client);
    return room;
  }
}

class _LocalCollaborationRoom {
  _LocalCollaborationRoom(this.workspaceId);

  final String workspaceId;
  final _members = <String, CollaborationTransportClient>{};
  final _presence = <String, CollaborationPeer>{};
  final _snapshots = <String, String>{};

  void join(CollaborationTransportClient client) {
    _members[client.peerId] = client;
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
      member.publishPeers(peers);
    }
  }

  void broadcastTextUpdate(CollaborationTextUpdate update) {
    _snapshots[update.filePath] = _applyOperation(
      _snapshots[update.filePath] ?? '',
      update.operation,
    );
    for (final member in _members.values) {
      if (member.peerId == update.peerId) continue;
      member.receiveTextUpdate(update);
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
