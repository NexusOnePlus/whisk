import 'package:flutter/foundation.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace }

class AppShellViewModel extends ChangeNotifier {
  AppShellMode _mode = AppShellMode.dashboard;
  WorkspaceViewModel? _workspaceViewModel;

  AppShellMode get mode => _mode;
  WorkspaceViewModel? get workspaceViewModel => _workspaceViewModel;

  void openDraftWorkspace() {
    _workspaceViewModel = WorkspaceViewModel();
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
