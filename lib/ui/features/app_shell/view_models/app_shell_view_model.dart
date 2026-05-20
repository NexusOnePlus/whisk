import 'package:flutter/material.dart';
import 'package:whisk/data/services/collaboration_service_p2p.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace, localCollaboration }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()});

  final ProjectOpenService _projectOpenService;
  AppShellMode _mode = AppShellMode.dashboard;
  WorkspaceViewModel? _workspaceViewModel;
  List<WorkspaceViewModel> _collaborationViewModels = const [];
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

    _collaborationViewModels = [
      WorkspaceViewModel(
        collaborationService: CollaborationServiceP2p(
          peerId: 'local-left',
          peerName: 'Local instance',
          peerColor: Colors.cyanAccent,
        ),
      ),
      WorkspaceViewModel(
        collaborationService: CollaborationServiceP2p(
          peerId: 'local-right',
          peerName: 'Second perspective',
          peerColor: Colors.orangeAccent,
        ),
      ),
    ];
    _workspaceViewModel = null;
    _mode = AppShellMode.localCollaboration;
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
