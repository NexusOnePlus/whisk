import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/preview_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/sidebar.dart';
import 'package:whisk/ui/features/workspace/widgets/source_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/top_bar.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_rail.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.viewModel,
    required this.onCloseWorkspace,
  });

  final WorkspaceViewModel viewModel;
  final VoidCallback onCloseWorkspace;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final TextEditingController _controller;

  WorkspaceViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: viewModel.activeFile.content);
    viewModel.addListener(_syncControllerFromModel);
  }

  @override
  void dispose() {
    viewModel.removeListener(_syncControllerFromModel);
    _controller.dispose();
    super.dispose();
  }

  void _syncControllerFromModel() {
    final content = viewModel.activeFile.content;
    if (_controller.text == content) return;
    _controller.text = content;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 860;

                if (isCompact) {
                  return Column(
                    children: [
                      TopBar(
                        environment: viewModel.selectedEnvironment,
                        onCloseWorkspace: widget.onCloseWorkspace,
                      ),
                      Expanded(
                        child: _WorkspaceBody(
                          viewModel: viewModel,
                          controller: _controller,
                          compact: true,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const WorkspaceRail(),
                    Sidebar(environment: viewModel.selectedEnvironment),
                    Expanded(
                      child: Column(
                        children: [
                          TopBar(
                            environment: viewModel.selectedEnvironment,
                            onCloseWorkspace: widget.onCloseWorkspace,
                          ),
                          Expanded(
                            child: _WorkspaceBody(
                              viewModel: viewModel,
                              controller: _controller,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.viewModel,
    required this.controller,
    this.compact = false,
  });

  final WorkspaceViewModel viewModel;
  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final editor = SourcePane(
      environment: viewModel.selectedEnvironment,
      controller: controller,
      onChanged: viewModel.updateActiveContent,
    );
    final preview = PreviewPane(
      environment: viewModel.selectedEnvironment,
      result: viewModel.renderResult,
      onRender: viewModel.renderActiveFile,
    );

    if (compact) {
      return Column(
        children: [
          Expanded(child: editor),
          const Divider(height: 1, color: kBorder),
          Expanded(child: preview),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: editor),
        const VerticalDivider(width: 1, color: kBorder),
        Expanded(child: preview),
      ],
    );
  }
}
