import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service_p2p.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace, localCollaboration }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()});

  static const _localPeerColors = [
    Colors.cyanAccent,
    Colors.orangeAccent,
    Colors.limeAccent,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
    Colors.amberAccent,
  ];

  final ProjectOpenService _projectOpenService;
  AppShellMode _mode = AppShellMode.dashboard;
  WorkspaceViewModel? _workspaceViewModel;
  List<WorkspaceViewModel> _collaborationViewModels = const [];
  var _localPeerSequence = 0;
  var _disposed = false;

  AppShellMode get mode => _mode;
  WorkspaceViewModel? get workspaceViewModel => _workspaceViewModel;
  List<WorkspaceViewModel> get collaborationViewModels =>
      List.unmodifiable(_collaborationViewModels);

  void openDraftWorkspace() {
    if (_disposed) return;
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    _workspaceViewModel = WorkspaceViewModel(
      collaborationService: CollaborationServiceP2p(),
    );
    _mode = AppShellMode.workspace;
    notifyListeners();
  }

  void openLocalCollaborationDemo() {
    if (_disposed) return;
    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }

    _localPeerSequence = 0;
    _collaborationViewModels = [
      _createLocalCollaborationWorkspace(),
      _createLocalCollaborationWorkspace(),
    ];
    _workspaceViewModel = null;
    _mode = AppShellMode.localCollaboration;
    notifyListeners();
  }

  void addLocalCollaborationPerspective() {
    if (_disposed) return;
    if (_mode != AppShellMode.localCollaboration) return;

    _collaborationViewModels = [
      ..._collaborationViewModels,
      _createLocalCollaborationWorkspace(),
    ];
    notifyListeners();
  }

  void removeLocalCollaborationPerspective(WorkspaceViewModel workspace) {
    if (_disposed) return;
    if (_mode != AppShellMode.localCollaboration) return;
    if (!_collaborationViewModels.contains(workspace)) return;

    workspace.dispose();
    _collaborationViewModels = [
      for (final item in _collaborationViewModels)
        if (!identical(item, workspace)) item,
    ];

    if (_collaborationViewModels.isEmpty) {
      _mode = AppShellMode.dashboard;
    }
    notifyListeners();
  }

  Future<void> openLatexProject() async {
    final project = await _projectOpenService.pickLatexProject();
    if (_disposed) return;
    if (project == null) return;

    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    final workspace = WorkspaceViewModel(
      initialFile: project.entryFile,
      projectFiles: project.files,
      collaborationService: CollaborationServiceP2p(),
    );
    _workspaceViewModel = workspace;
    _mode = AppShellMode.workspace;
    notifyListeners();

    if (project.entryFile.extension == '.tex') {
      await workspace.renderActiveFile();
    }
  }

  void closeWorkspace() {
    if (_disposed) return;
    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _workspaceViewModel = null;
    _collaborationViewModels = const [];
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }

  WorkspaceViewModel _createLocalCollaborationWorkspace() {
    final sequence = _localPeerSequence++;
    final number = sequence + 1;
    return WorkspaceViewModel(
      collaborationService: CollaborationServiceP2p(
        peerId: 'local-peer-$number',
        peerName: 'Perspective $number',
        peerColor: _localPeerColors[sequence % _localPeerColors.length],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    super.dispose();
  }
}
