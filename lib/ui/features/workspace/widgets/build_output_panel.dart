import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class BuildOutputPanel extends StatelessWidget {
  const BuildOutputPanel({
    super.key,
    required this.environment,
    required this.renderResult,
  });

  final EnvironmentKind environment;
  final RenderResult renderResult;

  @override
  Widget build(BuildContext context) {
    final log = renderResult.log.trim();
    if (log.isEmpty && !renderResult.isRendering) {
      return _buildEmpty();
    }
    if (renderResult.isRendering) {
      return _buildRendering();
    }

    final lines = log.split('\n');
    final hasErrors = lines.any((l) =>
        l.contains(RegExp(r'error', caseSensitive: false)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(hasErrors),
        const Divider(color: kBorder, height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const TextSpan(text: '\n'),
                    _lineSpan(lines[i]),
                  ],
                ],
              ),
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _lineSpan(String line) {
    final isError = line.contains(RegExp(r'error', caseSensitive: false));
    final isWarning = line.contains(RegExp(r'warning', caseSensitive: false));
    final color = isError
        ? kDangerRed
        : isWarning
            ? kAccentAmber
            : kTextSecondary;
    return TextSpan(text: line, style: TextStyle(color: color));
  }

  Widget _buildHeader(bool hasErrors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(
            hasErrors ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: hasErrors ? kDangerRed : kSuccessGreen,
          ),
          const SizedBox(width: 8),
          Text(
            environment.name,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (hasErrors)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kDangerRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'errors',
                style: TextStyle(
                  color: kDangerRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal, color: kTextMuted.withValues(alpha: 0.4), size: 28),
          const SizedBox(height: 12),
          const Text(
            'No output yet',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Render a document to see\nbuild output here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildRendering() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 12),
          Text(
            'Rendering...',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
