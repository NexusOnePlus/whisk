import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/app_shell/view_models/app_shell_view_model.dart';
import 'package:whisk/ui/features/app_shell/widgets/about_dialog.dart' as whisk;
import 'package:whisk/ui/features/app_shell/widgets/app_sidebar.dart';
import 'package:whisk/ui/features/dashboard/views/dashboard_content.dart';
import 'package:whisk/ui/features/workspace/views/workspace_content.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppShellViewModel viewModel;
  final _sidebarKey = GlobalKey<AppSidebarState>();

  @override
  void initState() {
    super.initState();
    viewModel = AppShellViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final isWorkspace = viewModel.mode == AppShellMode.workspace;

        if (isWorkspace) {
          _sidebarKey.currentState?.setWorkspaceMode(true);
        } else {
          _sidebarKey.currentState?.setWorkspaceMode(false);
        }

        return Scaffold(
          backgroundColor: kAppBlack,
          body: SafeArea(
            child: Row(
              children: [
                AppSidebar(
                  key: _sidebarKey,
                  activeProjectTitle: viewModel.activeWorkspaceTitle,
                  openProjects: viewModel.openProjectPaths,
                  pinnedProjects: viewModel.pinnedProjects,
                  recentProjects: viewModel.recentProjects,
                  onSwitchProject: viewModel.switchToProject,
                  onTogglePin: viewModel.togglePinProject,
                  onCloseProject: viewModel.closeAndRemoveWorkspace,
                  onOpenRecentProject: viewModel.openRecentProject,
                  onRemoveRecentProject: viewModel.removeRecentProject,
                  onOpenDraftWorkspace: (int i) => viewModel.openDraftWorkspace(i),
                  onOpenFolder: viewModel.openProject,
                  onJoinSharedWorkspace: viewModel.joinSharedWorkspace,
                  onAbout: _showAbout,
                ),
                Container(width: 1, color: kBorder),
                Expanded(
                  child: _buildContent(isWorkspace),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isWorkspace) {
    if (isWorkspace) {
      return WorkspaceContent(
        viewModel: viewModel.workspaceViewModel!,
        onCloseWorkspace: viewModel.closeWorkspace,
        openProjects: viewModel.openProjectPaths,
        pinnedProjects: viewModel.pinnedProjects,
        onCloseProject: viewModel.closeAndRemoveWorkspace,
        onTogglePin: viewModel.togglePinProject,
        onSwitchProject: viewModel.switchToProject,
        onAbout: _showAbout,
      );
    }

    if (viewModel.mode == AppShellMode.localCollaboration) {
      return _LocalCollaborationWorkspace(viewModel: viewModel);
    }

    return DashboardContent(
      recentProjects: viewModel.recentProjects,
      onOpenDraftWorkspace: (int i) => viewModel.openDraftWorkspace(i),
      onOpenProject: viewModel.openProject,
      onOpenRecentProject: viewModel.openRecentProject,
      onRemoveRecentProject: viewModel.removeRecentProject,
      onOpenLocalCollaboration: viewModel.openLocalCollaborationDemo,
      onJoinSharedWorkspace: viewModel.joinSharedWorkspace,
      pinnedProjects: viewModel.pinnedProjects,
      onTogglePin: viewModel.togglePinProject,
      openProjects: viewModel.openProjectPaths,
      onSwitchProject: viewModel.switchToProject,
      onAbout: _showAbout,
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => const whisk.WhiskAboutDialog(),
    );
  }
}

class _LocalCollaborationWorkspace extends StatelessWidget {
  const _LocalCollaborationWorkspace({required this.viewModel});

  final AppShellViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final workspaces = viewModel.collaborationViewModels;
    return Column(
      children: [
        _LocalCollaborationToolbar(
          peerCount: workspaces.length,
          onAddPerspective: viewModel.addLocalCollaborationPerspective,
          onCloseWorkspace: viewModel.closeWorkspace,
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              for (final workspace in workspaces) ...[
                Expanded(
                  child: WorkspaceContent(
                    viewModel: workspace,
                    onCloseWorkspace: viewModel.closeWorkspace,
                    openProjects: viewModel.openProjectPaths,
                    pinnedProjects: viewModel.pinnedProjects,
                    onTogglePin: viewModel.togglePinProject,
                  ),
                ),
                if (workspace != workspaces.last)
                  const VerticalDivider(width: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalCollaborationToolbar extends StatelessWidget {
  const _LocalCollaborationToolbar({
    required this.peerCount,
    required this.onAddPerspective,
    required this.onCloseWorkspace,
  });

  final int peerCount;
  final VoidCallback onAddPerspective;
  final VoidCallback onCloseWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('Local collaboration demo', style: theme.textTheme.labelLarge),
          const SizedBox(width: 10),
          Text(
            '$peerCount perspectives',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddPerspective,
            icon: const Icon(Icons.add),
            label: const Text('Add editor'),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Close demo',
            onPressed: onCloseWorkspace,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
