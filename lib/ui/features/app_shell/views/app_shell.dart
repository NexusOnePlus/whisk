import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/app_shell/view_models/app_shell_view_model.dart';
import 'package:whisk/ui/features/app_shell/widgets/about_dialog.dart' as whisk;
import 'package:whisk/ui/features/app_shell/widgets/app_rail.dart';
import 'package:whisk/ui/features/dashboard/views/dashboard_content.dart';
import 'package:whisk/ui/features/projects/views/projects_content.dart';
import 'package:whisk/ui/features/workspace/views/workspace_content.dart';
import 'package:whisk/ui/features/workspace/widgets/settings_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppShellViewModel viewModel;
  RailTab _railTab = RailTab.home;

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

        return Scaffold(
          backgroundColor: kAppBlack,
          body: SafeArea(
            child: Row(
              children: [
                AppRail(
                  activeProjectTitle: viewModel.activeWorkspaceTitle,
                  openProjects: viewModel.openProjectPaths,
                  pinnedProjects: viewModel.pinnedProjects,
                  selectedTab: _railTab,
                  isInWorkspace: isWorkspace,
                  onSelectTab: (tab) {
                    if (isWorkspace) viewModel.closeWorkspace();
                    setState(() => _railTab = tab);
                  },
                  onSwitchProject: viewModel.switchToProject,
                  onTogglePin: viewModel.togglePinProject,
                  onSettings: _showSettings,
                ),
                Container(width: 1, color: kBorder),
                Expanded(child: _buildContent(isWorkspace)),
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
        onAbout: _showAbout,
      );
    }

    switch (_railTab) {
      case RailTab.projects:
        return ProjectsContent(
          openProjects: viewModel.openProjectPaths,
          pinnedProjects: viewModel.pinnedProjects,
          recentProjects: viewModel.recentProjects.map((p) => p.path).toList(),
          activeProjectTitle: viewModel.activeWorkspaceTitle,
          onSwitchProject: viewModel.switchToProject,
          onTogglePin: viewModel.togglePinProject,
          onRemoveProject: viewModel.removeRecentProject,
        );
      case RailTab.home:
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
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => const whisk.WhiskAboutDialog(),
    );
  }

  void _showSettings() {
    showDialog(context: context, builder: (_) => const SettingsDialog());
  }
}
