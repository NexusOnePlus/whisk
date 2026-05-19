import 'package:flutter/foundation.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()});

  final ProjectOpenService _projectOpenService;
  AppShellMode _mode = AppShellMode.dashboard;
  WorkspaceViewModel? _workspaceViewModel;

  AppShellMode get mode => _mode;
  WorkspaceViewModel? get workspaceViewModel => _workspaceViewModel;

  void openDraftWorkspace() {
    _workspaceViewModel = WorkspaceViewModel();
    _mode = AppShellMode.workspace;
    notifyListeners();
  }

  Future<void> openLatexProject() async {
    final file = await _projectOpenService.pickLatexProject();
    if (file == null) return;

    _workspaceViewModel?.dispose();
    _workspaceViewModel = WorkspaceViewModel(initialFile: file);
    _mode = AppShellMode.workspace;
    notifyListeners();
  }

  void closeWorkspace() {
    _workspaceViewModel?.dispose();
    _workspaceViewModel = null;
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }
}
