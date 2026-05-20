import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisk/data/services/collaboration_service.dart';
import 'package:whisk/data/services/document_render_service.dart';
import 'package:whisk/domain/models/collaboration_peer.dart';
import 'package:whisk/domain/models/collaboration_text_update.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

void main() {
  test(
    'guest collaboration saves do not write to the host file path',
    () async {
      final temp = await Directory.systemTemp.createTemp('whisk-save-test-');
      addTearDown(() => temp.delete(recursive: true));

      final source = File('${temp.path}${Platform.pathSeparator}main.tex');
      await source.writeAsString('host disk');
      final collaboration = _GuestAwareCollaborationService();
      final viewModel = WorkspaceViewModel(
        collaborationService: collaboration,
        initialFile: WhiskFile(
          path: source.path,
          name: 'main.tex',
          extension: '.tex',
          content: 'host disk',
          projectRoot: temp.path,
        ),
      );
      addTearDown(viewModel.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(await viewModel.joinCollaborationInvite('invite'), isTrue);
      viewModel.updateActiveContent('guest edit');
      await viewModel.saveActiveFile();

      final guestDraftPath = viewModel.guestDraftPathForTesting(source.path);
      expect(guestDraftPath, isNotNull);
      expect(await File(guestDraftPath!).readAsString(), 'guest edit');
      expect(await source.readAsString(), 'host disk');
      expect(viewModel.activeFile.content, 'guest edit');
      expect(viewModel.activeFile.isDirty, isFalse);
    },
  );

  test('guest collaboration renders from its draft workspace cache', () async {
    final temp = await Directory.systemTemp.createTemp('whisk-render-test-');
    addTearDown(() => temp.delete(recursive: true));

    final source = File('${temp.path}${Platform.pathSeparator}main.tex');
    await source.writeAsString('host disk');
    final collaboration = _GuestAwareCollaborationService();
    final renderService = _RecordingRenderService();
    final viewModel = WorkspaceViewModel(
      collaborationService: collaboration,
      initialFile: WhiskFile(
        path: source.path,
        name: 'main.tex',
        extension: '.tex',
        content: 'guest edit',
        projectRoot: temp.path,
      ),
      renderService: renderService,
    );
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(await viewModel.joinCollaborationInvite('invite'), isTrue);
    viewModel.updateActiveContent('guest render edit');
    await viewModel.saveActiveFile();
    final draftPath = viewModel.guestDraftPathForTesting(source.path);
    expect(draftPath, isNotNull);

    await viewModel.renderActiveFile();

    expect(renderService.lastFile, isNotNull);
    expect(renderService.lastFile!.path, draftPath);
    expect(renderService.lastFile!.content, 'guest render edit');
    expect(renderService.lastFile!.projectRoot, isNotNull);
    expect(renderService.lastFile!.projectRoot, isNot(temp.path));
  });
}

class _GuestAwareCollaborationService implements CollaborationService {
  final _peersController =
      StreamController<List<CollaborationPeer>>.broadcast();
  final _updatesController =
      StreamController<CollaborationTextUpdate>.broadcast();
  var _joined = false;

  @override
  String get peerId => 'guest';

  @override
  bool get canWriteLocalFiles => !_joined;

  @override
  Stream<List<CollaborationPeer>> get peers => _peersController.stream;

  @override
  Stream<CollaborationTextUpdate> get remoteTextUpdates =>
      _updatesController.stream;

  @override
  Future<void> connect(String workspaceId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> loadFileSnapshot(String filePath, String localContent) async {
    return localContent;
  }

  @override
  Future<String?> createInvite() async => 'invite';

  @override
  Future<bool> joinInvite(String invite) async {
    _joined = true;
    return true;
  }

  @override
  void updateLocalCursor(
    String filePath,
    int offset, {
    int? selectionStart,
    int? selectionEnd,
  }) {}

  @override
  void broadcastTextChange(CollaborationTextUpdate update) {}
}

class _RecordingRenderService extends DocumentRenderService {
  WhiskFile? lastFile;

  @override
  Future<RenderResult> render({
    required String environmentId,
    required WhiskFile file,
  }) async {
    lastFile = file;
    return const RenderResult.idle();
  }
}
