import 'package:whisk/domain/models/collaboration_peer.dart';

abstract class CollaborationService {
  Stream<List<CollaborationPeer>> get peers;
  Stream<String> get remoteTextUpdates;

  Future<void> connect(String workspaceId);
  Future<void> disconnect();
  
  void updateLocalCursor(int offset, {int? selectionStart, int? selectionEnd});
  void broadcastTextChange(String newText);
}
