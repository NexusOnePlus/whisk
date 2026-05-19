import 'package:flutter/foundation.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()});

  final ProjectOpenService _projectOpenService;
  AppShellMode _mode = AppShellMode.dashboard;
  WorkspaceViewModel? _workspaceViewModel;
  var _disposed = false;

  AppShellMode get mode => _mode;
  WorkspaceViewModel? get workspaceViewModel => _workspaceViewModel;

  void openDraftWorkspace() {
    if (_disposed) return;
    _workspaceViewModel = WorkspaceViewModel();
    _mode = AppShellMode.workspace;
    notifyListeners();
  }

  Future<void> openLatexProject() async {
    final project = await _projectOpenService.pickLatexProject();
    if (_disposed) return;
    if (project == null) return;

    _workspaceViewModel?.dispose();
    final workspace = WorkspaceViewModel(
      initialFile: project.entryFile,
      projectFiles: project.files,
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
    _workspaceViewModel = null;
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _workspaceViewModel?.dispose();
    super.dispose();
  }
}
