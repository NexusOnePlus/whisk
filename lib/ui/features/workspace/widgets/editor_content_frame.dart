import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/sidebar.dart';
import 'package:whisk/ui/features/workspace/widgets/find_bar.dart';
import 'package:whisk/ui/features/workspace/widgets/editor_tab_bar.dart';
import 'package:whisk/ui/features/workspace/widgets/workspace_body.dart';

class EditorContentFrame extends StatefulWidget {
  const EditorContentFrame({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.editorFocusNode,
    required this.onEditorChanged,
    required this.revealRevision,
    this.revealOffset,
    required this.findOpen,
    required this.findController,
    required this.findFocusNode,
    required this.findMatches,
    required this.findCursor,
    required this.onToggleFind,
    required this.onRefreshFind,
    required this.onMoveFind,
  });

  final WorkspaceViewModel viewModel;
  final WhiskEditorController controller;
  final FocusNode editorFocusNode;
  final ValueChanged<String> onEditorChanged;
  final int revealRevision;
  final int? revealOffset;
  final bool findOpen;
  final TextEditingController findController;
  final FocusNode findFocusNode;
  final List<int> findMatches;
  final int findCursor;
  final VoidCallback onToggleFind;
  final VoidCallback onRefreshFind;
  final void Function(int) onMoveFind;

  @override
  State<EditorContentFrame> createState() => _EditorContentFrameState();
}

class _EditorContentFrameState extends State<EditorContentFrame> {
  ProjectSidebarSection _section = ProjectSidebarSection.files;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                Expanded(
                  child: Sidebar(
                    section: _section,
                    file: vm.activeFile,
                    files: vm.projectFiles,
                    environment: vm.selectedEnvironment,
                    renderResult: vm.renderResult,
                    onOpenFile: vm.openFile,
                    onNewFile: vm.createFile,
                    onNewFolder: vm.createFolder,
                    onDeleteFile: vm.deleteFile,
                  ),
                ),
                SidebarPill(
                  section: _section,
                  onChanged: (s) => setState(() => _section = s),
                ),
              ],
            ),
          ),
          Container(width: 1, color: kBorder),
          Expanded(
            child: Column(
              children: [
                EditorTabBar(
                  file: vm.activeFile,
                  openFiles: vm.openFiles,
                  onSelectFile: vm.openFile,
                  onCloseFile: vm.closeFile,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.findOpen)
                        FindBar(
                          controller: widget.findController,
                          focusNode: widget.findFocusNode,
                          matchCount: widget.findMatches.length,
                          currentMatch: widget.findMatches.isEmpty
                              ? 0
                              : widget.findCursor + 1,
                          onChanged: (_) => widget.onRefreshFind(),
                          onPrevious: () => widget.onMoveFind(-1),
                          onNext: () => widget.onMoveFind(1),
                          onClose: widget.onToggleFind,
                        ),
                      Expanded(
                        child: WorkspaceBody(
                          viewModel: vm,
                          controller: widget.controller,
                          editorFocusNode: widget.editorFocusNode,
                          onEditorChanged: widget.onEditorChanged,
                          revealRevision: widget.revealRevision,
                          revealOffset: widget.revealOffset,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarPill extends StatelessWidget {
  const SidebarPill({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final ProjectSidebarSection section;
  final ValueChanged<ProjectSidebarSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _PillButton(
            icon: Icons.folder_outlined,
            label: 'Explorer',
            selected: section == ProjectSidebarSection.files,
            onTap: () => onChanged(ProjectSidebarSection.files),
          ),
          const SizedBox(width: 4),
          _PillButton(
            icon: Icons.search,
            label: 'Search',
            selected: section == ProjectSidebarSection.search,
            onTap: () => onChanged(ProjectSidebarSection.search),
          ),
          const SizedBox(width: 4),
          _PillButton(
            icon: Icons.error_outline,
            label: 'Errors',
            selected: section == ProjectSidebarSection.diagnostics,
            onTap: () => onChanged(ProjectSidebarSection.diagnostics),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? kGlassHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: selected ? kTextPrimary : kTextMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? kTextPrimary : kTextMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
