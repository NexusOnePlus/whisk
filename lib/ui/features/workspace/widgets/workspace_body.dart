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
    if (active.path.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, color: kTextMuted, size: 36),
            SizedBox(height: 12),
            Text(
              'No files open',
              style: TextStyle(color: kTextMuted, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Open a file from the sidebar\nto start editing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted, fontSize: 11),
            ),
          ],
        ),
      );
    }
    final Widget editor;
    if (active.isImage) {
      editor = ImageFilePane(file: active);
    } else if (active.isPdf) {
      editor = ExcludeSemantics(
        child: PdfViewer.file(
          active.path,
          key: ValueKey(active.path),
          params: PdfViewerParams(
            backgroundColor: Colors.transparent,
            errorBannerBuilder: (context, error, stackTrace, documentRef) =>
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf, color: kTextMuted, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Could not open PDF',
                        style: const TextStyle(color: kTextMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
          ),
        ),
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
