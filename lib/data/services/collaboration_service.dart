import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';

abstract class CollaborationService {
  String get peerId;
  Stream<List<CollaborationPeer>> get peers;
  Stream<CollaborationTextUpdate> get remoteTextUpdates;

  Future<void> connect(String workspaceId);
  Future<void> disconnect();
  Future<String> loadFileSnapshot(String filePath, String localContent);
  Future<String?> createInvite();
  Future<bool> joinInvite(String invite);

  void updateLocalCursor(
    String filePath,
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  });
  void broadcastTextChange(CollaborationTextUpdate update);
}
