import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class PreviewPane extends StatelessWidget {
  const PreviewPane({
    super.key,
    required this.environment,
    required this.result,
    required this.onRender,
  });

  final EnvironmentKind environment;
  final RenderResult result;
  final VoidCallback onRender;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAppBlack,
      child: switch (result.state) {
        RenderState.rendering => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        RenderState.success when result.pdfPath != null => PdfViewer.file(
          result.pdfPath!,
          key: ValueKey(result.pdfPath),
        ),
        RenderState.failed => Center(
          child: Text('Render failed', style: TextStyle(color: kDangerRed)),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
