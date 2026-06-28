import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/collaboration_service_p2p.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/data/services/recent_project_service.dart';
import 'package:whisk/domain/models/recent_project.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace, localCollaboration }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()}) {
    _recentProjectService.addListener(_onRecentsChanged);
    _recentProjectService.load();
  }

  final RecentProjectService _recentProjectService = RecentProjectService();
  List<RecentProject> get recentProjects => _recentProjectService.projects;

  void _onRecentsChanged() => notifyListeners();

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
  String? get activeWorkspaceTitle {
    final workspace = _workspaceViewModel;
    if (workspace == null) return null;
    final root = workspace.activeFile.projectRoot;
    if (root == null) return 'Shared workspace';
    return root.split(RegExp(r'[\\/]')).last;
  }

  List<WorkspaceViewModel> get collaborationViewModels =>
      List.unmodifiable(_collaborationViewModels);

  void openDraftWorkspace(int envIndex) {
    if (_disposed) return;
    final env = const EnvironmentCatalog().listEnvironments()[envIndex];
    final rootPath = WorkspaceViewModel.computeDraftRootPath(env);
    _recentProjectService.save(RecentProject(
      path: rootPath,
      name: rootPath.split(Platform.pathSeparator).last,
      type: env.id,
      lastOpened: DateTime.now().millisecondsSinceEpoch,
    ));
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    _workspaceViewModel = WorkspaceViewModel(
      startEnvIndex: envIndex,
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

  void _saveRecentForPath(String path, String type) {
    _recentProjectService.save(RecentProject(
      path: path,
      name: path.split(Platform.pathSeparator).last,
      type: type,
      lastOpened: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> openProject() async {
    final project = await _projectOpenService.pickProject();
    if (_disposed) return;
    if (project == null) return;

    final rootPath = project.rootPath;
    _saveRecentForPath(rootPath, 'folder');

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

  Future<bool> joinSharedWorkspace(String invite) async {
    if (_disposed) return false;
    final service = CollaborationServiceP2p(peerName: 'Guest');
    await service.connect('guest-${DateTime.now().microsecondsSinceEpoch}');
    if (_disposed) {
      await service.disconnect();
      return false;
    }
    final joined = await service.joinInvite(invite);
    if (!joined) {
      await service.disconnect();
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final remoteFiles = await service.requestRemoteFiles();
    if (_disposed) {
      await service.disconnect();
      return false;
    }
    final files = remoteFiles.isEmpty
        ? const [
            WhiskFile(
              path: 'shared/main.tex',
              name: 'main.tex',
              extension: '.tex',
              content: '',
            ),
          ]
        : [
            for (final file in remoteFiles)
              WhiskFile(
                path: file.path,
                name: file.name,
                extension: file.extension,
                content: '',
              ),
          ];

    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    _workspaceViewModel = WorkspaceViewModel(
      initialFile: files.first,
      projectFiles: files,
      collaborationService: service,
    );
    _mode = AppShellMode.workspace;
    notifyListeners();
    return true;
  }

  void showDashboard() {
    if (_disposed) return;
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }

  void resumeActiveWorkspace() {
    if (_disposed) return;
    if (_workspaceViewModel == null) return;
    _mode = AppShellMode.workspace;
    notifyListeners();
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
