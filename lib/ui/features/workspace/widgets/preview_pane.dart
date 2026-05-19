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
    final canRender = environment.id == 'latex' && !result.isRendering;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PreviewPill(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF preview',
                color: kAccentBlue,
              ),
              const SizedBox(width: 8),
              _PreviewPill(label: _statusLabel(result)),
              const Spacer(),
              TextButton.icon(
                onPressed: canRender ? onRender : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(result.isRendering ? 'Rendering' : 'Render'),
                style: TextButton.styleFrom(
                  foregroundColor: kAppBlack,
                  backgroundColor: kTextPrimary,
                  disabledForegroundColor: kTextMuted,
                  disabledBackgroundColor: kPanelRaised,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Export',
                onPressed: () {},
                icon: const Icon(Icons.file_upload_outlined),
                color: kTextSecondary,
              ),
              IconButton(
                tooltip: 'Zoom',
                onPressed: () {},
                icon: const Icon(Icons.zoom_in),
                color: kTextSecondary,
              ),
              IconButton(
                tooltip: 'Preview options',
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
                color: kTextSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _PreviewSurface(environment: environment, result: result),
          ),
        ],
      ),
    );
  }

  String _statusLabel(RenderResult result) {
    return switch (result.state) {
      RenderState.idle => 'idle',
      RenderState.rendering => 'running',
      RenderState.success => result.engine ?? 'ready',
      RenderState.failed => 'failed',
    };
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kPanelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? kTextSecondary, size: 16),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: const TextStyle(color: kTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PreviewStatusGrid extends StatelessWidget {
  const _PreviewStatusGrid({required this.result});

  final RenderResult result;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        const _PreviewMetric(label: 'Diagnostics', value: '0'),
        _PreviewMetric(label: 'Engine', value: result.engine ?? '--'),
        _PreviewMetric(label: 'PDF', value: result.hasPdf ? 'ready' : '--'),
      ],
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.environment, required this.result});

  final EnvironmentKind environment;
  final RenderResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
        gradient: result.hasPdf
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentBlue.withValues(alpha: 0.12),
                  kPanel,
                  kSuccessGreen.withValues(alpha: 0.05),
                ],
                stops: const [0, 0.45, 1],
              ),
      ),
      child: switch (result.state) {
        RenderState.rendering => const _RenderingState(),
        RenderState.success when result.pdfPath != null => PdfViewer.file(
          result.pdfPath!,
          key: ValueKey(result.pdfPath),
        ),
        RenderState.failed => _PreviewMessage(
          environment: environment,
          title: 'Render failed',
          message: result.log,
          result: result,
        ),
        _ => _PreviewMessage(
          environment: environment,
          title: '${environment.name} preview',
          message: environment.id == 'latex'
              ? 'Press Render to compile the active .tex file into a PDF.'
              : 'This renderer is queued for a later phase.',
          result: result,
        ),
      },
    );
  }
}

class _RenderingState extends StatelessWidget {
  const _RenderingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 14),
          Text(
            'Compiling LaTeX...',
            style: TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.environment,
    required this.title,
    required this.message,
    required this.result,
  });

  final EnvironmentKind environment;
  final String title;
  final String message;
  final RenderResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(environment.icon, color: kAccentBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                environment.extension,
                style: const TextStyle(
                  color: kTextMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                message,
                style: const TextStyle(color: kTextSecondary, height: 1.35),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PreviewStatusGrid(result: result),
          const SizedBox(height: 20),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [kAccentBlue, kSuccessGreen],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: kTextMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
