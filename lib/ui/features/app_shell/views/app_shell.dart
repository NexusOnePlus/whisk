import 'package:flutter/material.dart';
import 'package:whisk/ui/features/app_shell/view_models/app_shell_view_model.dart';
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
            onOpenDraftWorkspace: viewModel.openDraftWorkspace,
            onOpenLatexProject: viewModel.openLatexProject,
            onOpenLocalCollaboration: viewModel.openLocalCollaborationDemo,
          ),
          AppShellMode.workspace => WorkspaceScreen(
            viewModel: viewModel.workspaceViewModel!,
            onCloseWorkspace: viewModel.closeWorkspace,
          ),
          AppShellMode.localCollaboration => Row(
            children: [
              for (final workspace in viewModel.collaborationViewModels) ...[
                Expanded(
                  child: WorkspaceScreen(
                    viewModel: workspace,
                    onCloseWorkspace: viewModel.closeWorkspace,
                  ),
                ),
                if (workspace != viewModel.collaborationViewModels.last)
                  const VerticalDivider(width: 1),
              ],
            ],
          ),
        };
      },
    );
  }
}
