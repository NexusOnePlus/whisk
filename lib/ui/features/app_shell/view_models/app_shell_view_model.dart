import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/collaboration_service_p2p.dart';
import 'package:whisk/data/services/invite_codec.dart';
import 'package:whisk/data/services/pinned_project_service.dart';
import 'package:whisk/data/services/project_open_service.dart';
import 'package:whisk/data/services/recent_project_service.dart';
import 'package:whisk/data/services/project_tags_service.dart';
import 'package:whisk/data/services/settings_service.dart';
import 'package:whisk/data/services/workspace_config_service.dart';
import 'package:whisk/domain/models/recent_project.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';

enum AppShellMode { dashboard, workspace, localCollaboration }

class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({this._projectOpenService = const ProjectOpenService()}) {
    _recentProjectService.addListener(_onRecentsChanged);
    _recentProjectService.load();
    _pinnedProjectService.addListener(_onPinnedChanged);
    _pinnedProjectService.load();
    SettingsService.instance.load();
    ProjectTagsService.instance.load();
  }

  final RecentProjectService _recentProjectService = RecentProjectService();
  final PinnedProjectService _pinnedProjectService = PinnedProjectService();
  List<RecentProject> get recentProjects => _recentProjectService.projects;
  List<String> get pinnedProjects => _pinnedProjectService.pinnedPaths;

  void _onRecentsChanged() => notifyListeners();
  void _onPinnedChanged() => notifyListeners();

  void togglePinProject(String path) {
    _pinnedProjectService.toggle(path);
  }

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
  final List<String> _openProjectPaths = [];
  var _localPeerSequence = 0;
  var _disposed = false;
  bool _isJoining = false;

  AppShellMode get mode => _mode;
  bool get isJoining => _isJoining;
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

  List<String> get openProjectPaths => List.unmodifiable(_openProjectPaths);

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
    _workspaceViewModel?.dispose();
    _workspaceViewModel = WorkspaceViewModel(
      startEnvIndex: envIndex,
      collaborationService: CollaborationServiceP2p(
        peerName: SettingsService.instance.profileName.isNotEmpty
            ? SettingsService.instance.profileName
            : null,
      ),
    );
    _addOpenProject(rootPath);
    _mode = AppShellMode.workspace;
    notifyListeners();
  }

  void _addOpenProject(String path) {
    _openProjectPaths.remove(path);
    _openProjectPaths.add(path);
  }

  void _removeOpenProject(String path) {
    _openProjectPaths.remove(path);
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

  void _saveRecentForPath(String path, String type, {String? lastFilePath}) {
    final existing = _recentProjectService.projects
        .where((p) => p.path == path)
        .firstOrNull;
    _recentProjectService.save(RecentProject(
      path: path,
      name: path.split(Platform.pathSeparator).last,
      type: type,
      lastOpened: DateTime.now().millisecondsSinceEpoch,
      lastFilePath: lastFilePath ?? existing?.lastFilePath,
    ));
  }

  Future<void> openProject() async {
    final project = await _projectOpenService.pickProject();
    if (_disposed) return;
    if (project == null) return;

    final rootPath = project.rootPath;
    _saveRecentForPath(rootPath, 'folder', lastFilePath: project.entryFile.path);
    unawaited(WorkspaceConfig.ensureDefaults(rootPath));

    final envIndex = const EnvironmentCatalog().listEnvironments().indexWhere(
      (e) => e.extension == project.entryFile.extension,
    );

    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    final workspace = WorkspaceViewModel(
      initialFile: project.entryFile,
      projectFiles: project.files,
      startEnvIndex: envIndex >= 0 ? envIndex : 0,
      collaborationService: CollaborationServiceP2p(
        peerName: SettingsService.instance.profileName.isNotEmpty
            ? SettingsService.instance.profileName
            : null,
      ),
    );
    _workspaceViewModel = workspace;
    _addOpenProject(rootPath);
    _mode = AppShellMode.workspace;
    notifyListeners();

    await workspace.renderActiveFile();
  }

  Future<bool> joinSharedWorkspace(String invite) async {
    if (_disposed) return false;
    _isJoining = true;
    notifyListeners();

    final payload = InviteCodec.decode(invite);
    final ticket = payload?.ticket ?? invite;

    final guestName = SettingsService.instance.profileName.isNotEmpty
        ? SettingsService.instance.profileName
        : (payload?.hostName.isNotEmpty == true ? 'Guest of ${payload!.hostName}' : 'Guest');
    final service = CollaborationServiceP2p(peerName: guestName);
    await service.connect('guest-${DateTime.now().microsecondsSinceEpoch}');
    if (_disposed) {
      await service.disconnect();
      _isJoining = false;
      notifyListeners();
      return false;
    }
    final joined = await service.joinInvite(ticket);
    if (!joined) {
      await service.disconnect();
      _isJoining = false;
      notifyListeners();
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    final remoteFiles = await service.requestRemoteFiles();
    if (_disposed) {
      await service.disconnect();
      _isJoining = false;
      notifyListeners();
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
    _isJoining = false;
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
    _saveCurrentWorkspaceState();
    _workspaceViewModel?.dispose();
    _workspaceViewModel = null;
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }

  void closeAndRemoveWorkspace() {
    if (_disposed) return;
    _saveCurrentWorkspaceState();
    final workspace = _workspaceViewModel;
    if (workspace != null) {
      final root = workspace.activeFile.projectRoot;
      if (root != null) _removeOpenProject(root);
    }
    _workspaceViewModel?.dispose();
    _workspaceViewModel = null;
    _mode = AppShellMode.dashboard;
    notifyListeners();
  }

  void _saveCurrentWorkspaceState() {
    final workspace = _workspaceViewModel;
    if (workspace == null) return;
    final root = workspace.activeFile.projectRoot;
    if (root == null) return;
    final type = workspace.selectedEnvironment.id;
    _saveRecentForPath(root, type, lastFilePath: workspace.activeFile.path);
  }

  Future<void> openRecentProject(RecentProject project) async {
    if (_disposed) return;
    final root = Directory(project.path);
    if (!await root.exists()) return;
    unawaited(WorkspaceConfig.ensureDefaults(project.path));

    final diskProject = await _projectOpenService.pickProjectFromPath(project.path);
    if (_disposed) return;
    if (diskProject == null) return;

    WhiskFile initialFile = diskProject.entryFile;
    int envIndex = const EnvironmentCatalog().listEnvironments().indexWhere(
      (e) => e.extension == diskProject.entryFile.extension,
    );

    if (project.lastFilePath != null) {
      final saved = diskProject.files
          .where((f) => f.path == project.lastFilePath)
          .firstOrNull;
      if (saved != null) {
        initialFile = saved;
        envIndex = const EnvironmentCatalog().listEnvironments().indexWhere(
          (e) => e.extension == saved.extension,
        );
      }
    }

    _recentProjectService.save(RecentProject(
      path: project.path,
      name: project.name,
      type: project.type,
      lastOpened: DateTime.now().millisecondsSinceEpoch,
      lastFilePath: initialFile.path,
    ));

    _workspaceViewModel?.dispose();
    for (final workspace in _collaborationViewModels) {
      workspace.dispose();
    }
    _collaborationViewModels = const [];
    final workspace = WorkspaceViewModel(
      initialFile: initialFile,
      projectFiles: diskProject.files,
      startEnvIndex: envIndex >= 0 ? envIndex : 0,
      collaborationService: CollaborationServiceP2p(
        peerName: SettingsService.instance.profileName.isNotEmpty
            ? SettingsService.instance.profileName
            : null,
      ),
    );
    _workspaceViewModel = workspace;
    _addOpenProject(project.path);
    _mode = AppShellMode.workspace;
    notifyListeners();

    await workspace.renderActiveFile();
  }

  void removeRecentProject(String path) {
    _recentProjectService.remove(path);
  }

  Future<void> switchToProject(String path) async {
    if (_disposed) return;
    if (_workspaceViewModel?.activeFile.projectRoot == path) return;

    final existing = _recentProjectService.projects
        .where((p) => p.path == path)
        .firstOrNull;
    final project = existing ?? RecentProject(
      path: path,
      name: path.split(Platform.pathSeparator).last,
      type: 'folder',
      lastOpened: DateTime.now().millisecondsSinceEpoch,
    );
    await openRecentProject(project);
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
    _recentProjectService.removeListener(_onRecentsChanged);
    _pinnedProjectService.removeListener(_onPinnedChanged);
    super.dispose();
  }
}
