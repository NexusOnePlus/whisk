import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

abstract class CollaborationService {
  Stream<List<CollaborationPeer>> get peers;
  Stream<EditorTextOperation> get remoteTextUpdates;

  Future<void> connect(String workspaceId);
  Future<void> disconnect();

  void updateLocalCursor(int offset, {int? selectionStart, int? selectionEnd});
  void broadcastTextChange(EditorTextOperation operation);
}
