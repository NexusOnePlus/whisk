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

  test('streams text deltas to every remote peer in a room', () async {
    final workspaceId =
        'workspace-multiplex-${DateTime.now().microsecondsSinceEpoch}';
    final peers = [
      for (var index = 0; index < 5; index++)
        CollaborationServiceP2p.localOnly(
          peerId: 'peer-$index',
          peerName: 'Peer $index',
        ),
    ];

    for (final peer in peers) {
      await peer.connect(workspaceId);
      await peer.loadFileSnapshot('/main.tex', 'abc');
      addTearDown(peer.disconnect);
    }

    final receivedByGuests = [
      for (final peer in peers.skip(1)) peer.remoteTextUpdates.first,
    ];
    peers.first.broadcastTextChange(
      const CollaborationTextUpdate(
        peerId: 'peer-0',
        filePath: '/main.tex',
        operation: EditorTextOperation(
          offset: 2,
          deletedText: '',
          insertedText: 'Z',
        ),
      ),
    );

    final updates = await Future.wait(receivedByGuests);
    expect(updates, hasLength(4));
    for (final update in updates) {
      expect(update.peerId, 'peer-0');
      expect(update.filePath, '/main.tex');
      expect(update.operation.offset, 2);
      expect(update.operation.insertedText, 'Z');
      expect(update.operation.deletedText, isEmpty);
    }
  });

  test('keeps lazy snapshots isolated per file', () async {
    final workspaceId =
        'workspace-file-scope-${DateTime.now().microsecondsSinceEpoch}';
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

    await host.loadFileSnapshot('/main.tex', 'main from host');
    await host.loadFileSnapshot('/chapter.tex', 'chapter from host');

    expect(
      await guest.loadFileSnapshot('/main.tex', 'main from guest'),
      'main from host',
    );
    expect(
      await guest.loadFileSnapshot('/chapter.tex', 'chapter from guest'),
      'chapter from host',
    );
  });

  test('late joiners receive snapshots after previous deltas', () async {
    final workspaceId =
        'workspace-late-join-${DateTime.now().microsecondsSinceEpoch}';
    final host = CollaborationServiceP2p.localOnly(
      peerId: 'host',
      peerName: 'Host',
    );
    final earlyGuest = CollaborationServiceP2p.localOnly(
      peerId: 'early',
      peerName: 'Early Guest',
    );
    final lateGuest = CollaborationServiceP2p.localOnly(
      peerId: 'late',
      peerName: 'Late Guest',
    );

    await host.connect(workspaceId);
    await earlyGuest.connect(workspaceId);
    await host.loadFileSnapshot('/main.tex', 'abc');
    await earlyGuest.loadFileSnapshot('/main.tex', 'abc');
    addTearDown(host.disconnect);
    addTearDown(earlyGuest.disconnect);
    addTearDown(lateGuest.disconnect);

    final earlyUpdate = earlyGuest.remoteTextUpdates.first;
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
    await earlyUpdate;

    await lateGuest.connect(workspaceId);
    expect(await lateGuest.loadFileSnapshot('/main.tex', 'stale'), 'aXbc');
  });

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

  test('presence publishes multiple remote cursors and selections', () async {
    final workspaceId =
        'workspace-multi-presence-${DateTime.now().microsecondsSinceEpoch}';
    final viewer = CollaborationServiceP2p.localOnly(
      peerId: 'viewer',
      peerName: 'Viewer',
    );
    final editorA = CollaborationServiceP2p.localOnly(
      peerId: 'editor-a',
      peerName: 'Editor A',
    );
    final editorB = CollaborationServiceP2p.localOnly(
      peerId: 'editor-b',
      peerName: 'Editor B',
    );

    await viewer.connect(workspaceId);
    await editorA.connect(workspaceId);
    await editorB.connect(workspaceId);
    addTearDown(viewer.disconnect);
    addTearDown(editorA.disconnect);
    addTearDown(editorB.disconnect);

    final nextPeers = viewer.peers.firstWhere(
      (peers) =>
          peers.any((peer) => peer.id == 'editor-a') &&
          peers.any((peer) => peer.id == 'editor-b'),
    );
    editorA.updateLocalCursor(
      '/main.tex',
      3,
      selectionStart: 1,
      selectionEnd: 3,
    );
    editorB.updateLocalCursor('/main.tex', 8);

    final peers = await nextPeers;
    final a = peers.singleWhere((peer) => peer.id == 'editor-a');
    final b = peers.singleWhere((peer) => peer.id == 'editor-b');

    expect(a.filePath, '/main.tex');
    expect(a.cursorOffset, 3);
    expect(a.selectionStart, 1);
    expect(a.selectionEnd, 3);
    expect(b.filePath, '/main.tex');
    expect(b.cursorOffset, 8);
    expect(b.selectionStart, isNull);
    expect(b.selectionEnd, isNull);
  });
}
