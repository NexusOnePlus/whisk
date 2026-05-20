import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';

abstract interface class CollaborationTransport {
  Future<void> connect({
    required String workspaceId,
    required CollaborationTransportClient client,
  });

  Future<void> disconnect();

  Future<String> loadFileSnapshot(String filePath, String localContent);

  void updatePresence(CollaborationPeer peer);

  void broadcastTextUpdate(CollaborationTextUpdate update);
}

abstract interface class CollaborationTransportClient {
  String get peerId;

  void receiveTextUpdate(CollaborationTextUpdate update);

  void publishPeers(List<CollaborationPeer> peers);
}
