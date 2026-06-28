import 'package:flutter/material.dart';
import 'package:whisk/ui/features/app_shell/view_models/app_shell_view_model.dart';
import 'package:whisk/ui/features/app_shell/widgets/about_dialog.dart';
import 'package:whisk/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:whisk/ui/features/workspace/views/workspace_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppShellViewModel viewModel;

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
        return switch (viewModel.mode) {
          AppShellMode.dashboard => DashboardScreen(
            recentProjects: viewModel.recentProjects,
            onOpenDraftWorkspace: (int i) => viewModel.openDraftWorkspace(i),
            onOpenProject: viewModel.openProject,
            onOpenRecentProject: viewModel.openRecentProject,
            onRemoveRecentProject: viewModel.removeRecentProject,
            onOpenLocalCollaboration: viewModel.openLocalCollaborationDemo,
            onJoinSharedWorkspace: viewModel.joinSharedWorkspace,
            activeWorkspaceTitle: viewModel.activeWorkspaceTitle,
            onResumeActiveWorkspace: viewModel.resumeActiveWorkspace,
            pinnedProjects: viewModel.pinnedProjects,
            onTogglePin: viewModel.togglePinProject,
            openProjects: viewModel.openProjectPaths,
            onSwitchProject: viewModel.switchToProject,
            onAbout: () => showDialog(
              context: context,
              builder: (_) => const AboutDialog(),
            ),
          ),
          AppShellMode.workspace => WorkspaceScreen(
            viewModel: viewModel.workspaceViewModel!,
            onCloseWorkspace: viewModel.closeWorkspace,
            openProjects: viewModel.openProjectPaths,
            pinnedProjects: viewModel.pinnedProjects,
            onCloseProject: viewModel.closeAndRemoveWorkspace,
            onTogglePin: viewModel.togglePinProject,
            onSwitchProject: viewModel.switchToProject,
            onAbout: () => showDialog(
              context: context,
              builder: (_) => const AboutDialog(),
            ),
          ),
          AppShellMode.localCollaboration => _LocalCollaborationWorkspace(
            viewModel: viewModel,
          ),
        };
      },
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
                  child: Column(
                    children: [
                      _LocalPerspectiveHeader(
                        title:
                            'Perspective ${workspaces.indexOf(workspace) + 1}',
                        canRemove: workspaces.length > 1,
                        onRemove: () {
                          viewModel.removeLocalCollaborationPerspective(
                            workspace,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: WorkspaceScreen(
                          viewModel: workspace,
                          onCloseWorkspace: viewModel.closeWorkspace,
                          openProjects: viewModel.openProjectPaths,
                          pinnedProjects: viewModel.pinnedProjects,
                          onTogglePin: viewModel.togglePinProject,
                        ),
                      ),
                    ],
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

class _LocalPerspectiveHeader extends StatelessWidget {
  const _LocalPerspectiveHeader({
    required this.title,
    required this.canRemove,
    required this.onRemove,
  });

  final String title;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
          IconButton(
            tooltip: 'Remove perspective',
            onPressed: canRemove ? onRemove : null,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
