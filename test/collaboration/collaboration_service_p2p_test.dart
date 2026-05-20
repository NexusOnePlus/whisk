import 'package:flutter_test/flutter_test.dart';
import 'package:whisk/data/services/collaboration_service_p2p.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/ui/features/editor/models/editor_text_operation.dart';

void main() {
  test('shares initial host snapshot lazily per file', () async {
    final workspaceId =
        'workspace-snapshot-${DateTime.now().microsecondsSinceEpoch}';
    final host = CollaborationServiceP2p.localOnly(
      peerId: 'host',
      peerName: 'Host',
    );
    final guest = CollaborationServiceP2p.localOnly(
      peerId: 'guest',
      peerName: 'Guest',
    );

    await host.connect(workspaceId);
    await guest.connect(workspaceId);
    addTearDown(host.disconnect);
    addTearDown(guest.disconnect);

    final hostSnapshot = await host.loadFileSnapshot('/main.tex', 'host text');
    final guestSnapshot = await guest.loadFileSnapshot(
      '/main.tex',
      'guest text',
    );

    expect(hostSnapshot, 'host text');
    expect(guestSnapshot, 'host text');
  });

  test(
    'streams text deltas to other peers without whole-file payloads',
    () async {
      final workspaceId =
          'workspace-delta-${DateTime.now().microsecondsSinceEpoch}';
      final host = CollaborationServiceP2p.localOnly(
        peerId: 'host',
        peerName: 'Host',
      );
      final guest = CollaborationServiceP2p.localOnly(
        peerId: 'guest',
        peerName: 'Guest',
      );

      await host.connect(workspaceId);
      await guest.connect(workspaceId);
      await host.loadFileSnapshot('/main.tex', 'abc');
      await guest.loadFileSnapshot('/main.tex', 'abc');
      addTearDown(host.disconnect);
      addTearDown(guest.disconnect);

      final nextUpdate = guest.remoteTextUpdates.first;
      host.broadcastTextChange(
        const CollaborationTextUpdate(
          peerId: 'host',
          filePath: '/main.tex',
          operation: EditorTextOperation(
            offset: 1,
            deletedText: '',
            insertedText: 'X',
          ),
        ),
      );

      final update = await nextUpdate;
      expect(update.peerId, 'host');
      expect(update.filePath, '/main.tex');
      expect(update.operation.offset, 1);
      expect(update.operation.insertedText, 'X');
      expect(update.operation.deletedText, isEmpty);
    },
  );

  test('broadcasts file-scoped cursor presence to peers', () async {
    final workspaceId =
        'workspace-presence-${DateTime.now().microsecondsSinceEpoch}';
    final host = CollaborationServiceP2p.localOnly(
      peerId: 'host',
      peerName: 'Host',
    );
    final guest = CollaborationServiceP2p.localOnly(
      peerId: 'guest',
      peerName: 'Guest',
    );

    await host.connect(workspaceId);
    await guest.connect(workspaceId);
    addTearDown(host.disconnect);
    addTearDown(guest.disconnect);

    final nextPeers = guest.peers.firstWhere(
      (peers) => peers.any((peer) => peer.id == 'host'),
    );
    host.updateLocalCursor('/main.tex', 4, selectionStart: 2, selectionEnd: 4);

    final peers = await nextPeers;
    final hostPeer = peers.singleWhere((peer) => peer.id == 'host');
    expect(hostPeer.filePath, '/main.tex');
    expect(hostPeer.cursorOffset, 4);
    expect(hostPeer.selectionStart, 2);
    expect(hostPeer.selectionEnd, 4);
  });
}
