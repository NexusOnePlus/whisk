import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart'
    hide MarkdownStyleSheet;
import 'package:pdfrx/pdfrx.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/ui/core/math_markdown_extension.dart';
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
    final envId = environment.id;
    if (envId == 'notes') {
      return _buildMarkdownPreview(context, result.content);
    }
    if (envId == 'mermaid') {
      return _buildMermaidPreview(result.content);
    }
    return _buildPdfViewer();
  }

  Widget _buildMarkdownPreview(BuildContext context, String? content) {
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      color: kAppBlack,
      child: Markdown(
        key: ValueKey(content.hashCode),
        data: content,
        selectable: true,
        padding: const EdgeInsets.all(24),
        blockSyntaxes: [BlockMathSyntax()],
        inlineSyntaxes: [InlineMathSyntax()],
        builders: {
          'math_block': MathBlockBuilder(),
          'math_inline': MathInlineBuilder(),
        },
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMermaidPreview(String? content) {
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      color: kAppBlack,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: MermaidDiagram(
            code: content,
            style: MermaidStyle.dark(),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return switch (result.state) {
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
          params: const PdfViewerParams(backgroundColor: Colors.transparent),
        ),
        RenderState.failed => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Render failed', style: TextStyle(color: kDangerRed)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRender,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        _ => Center(
          child: TextButton.icon(
            onPressed: onRender,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Render'),
          ),
        ),
      };
  }
}
