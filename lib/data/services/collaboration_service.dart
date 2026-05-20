import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_file_entry.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';

abstract class CollaborationService {
  String get peerId;
  bool get canWriteLocalFiles;
  Stream<List<CollaborationPeer>> get peers;
  Stream<List<CollaborationFileEntry>> get remoteFiles;
  Stream<CollaborationTextUpdate> get remoteTextUpdates;

  Future<void> connect(String workspaceId);
  Future<void> disconnect();
  Future<String> loadFileSnapshot(String filePath, String localContent);
  Future<String?> createInvite();
  Future<bool> joinInvite(String invite);
  Future<List<CollaborationFileEntry>> requestRemoteFiles();

  void updateWorkspaceFiles(List<CollaborationFileEntry> files);
  void updateLocalCursor(
    String filePath,
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  });
  void broadcastTextChange(CollaborationTextUpdate update);
}
