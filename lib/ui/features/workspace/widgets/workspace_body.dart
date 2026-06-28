import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:whisk/ui/core/whisk_colors.dart';
import 'package:whisk/ui/features/editor/logic/whisk_editor_controller.dart';
import 'package:whisk/ui/features/workspace/view_models/workspace_view_model.dart';
import 'package:whisk/ui/features/workspace/widgets/preview_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/source_pane.dart';
import 'package:whisk/ui/features/workspace/widgets/image_file_pane.dart';

class WorkspaceBody extends StatelessWidget {
  const WorkspaceBody({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.editorFocusNode,
    required this.onEditorChanged,
    required this.revealRevision,
    this.revealOffset,
  });

  final WorkspaceViewModel viewModel;
  final WhiskEditorController controller;
  final FocusNode editorFocusNode;
  final ValueChanged<String> onEditorChanged;
  final int revealRevision;
  final int? revealOffset;

  @override
  Widget build(BuildContext context) {
    final active = viewModel.activeFile;
    final Widget editor;
    if (active.isImage) {
      editor = ImageFilePane(file: active);
    } else if (active.isPdf) {
      editor = PdfViewer.file(
        active.path,
        key: ValueKey(active.path),
        params: const PdfViewerParams(backgroundColor: Colors.transparent),
      );
    } else {
      final remotePeers = viewModel.collaborationPeers
          .where((peer) => peer.filePath == active.path)
          .toList(growable: false);
      editor = SourcePane(
        environment: viewModel.selectedEnvironment,
        controller: controller,
        focusNode: editorFocusNode,
        remotePeers: remotePeers,
        revealRevision: revealRevision,
        revealOffset: revealOffset,
        onChanged: onEditorChanged,
      );
    }
    final preview = PreviewPane(
      environment: viewModel.selectedEnvironment,
      result: viewModel.renderResult,
      onRender: viewModel.renderActiveFile,
    );

    final showPreview = !active.isImage && !active.isPdf;

    if (!showPreview) {
      return editor;
    }

    return Row(
      children: [
        Expanded(child: editor),
        Container(width: 4, color: kBorder.withValues(alpha: 0.3)),
        Expanded(child: preview),
      ],
    );
  }
}
