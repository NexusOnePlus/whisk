import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class BuildOutputPanel extends StatefulWidget {
  const BuildOutputPanel({
    super.key,
    required this.environment,
    required this.renderResult,
  });

  final EnvironmentKind environment;
  final RenderResult renderResult;

  @override
  State<BuildOutputPanel> createState() => _BuildOutputPanelState();
}

class _BuildOutputPanelState extends State<BuildOutputPanel> {
  bool _showErrorsOnly = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.renderResult.log.trim();
    if (log.isEmpty) {
      return _buildEmpty();
    }

    final allLines = log.split('\n');
    final errorLines = allLines
        .where((l) => l.contains(RegExp(r'error|failed|denied', caseSensitive: false)))
        .toList();
    final displayLines = _showErrorsOnly ? errorLines : allLines;
    final hasErrors = errorLines.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(hasErrors, errorLines.length),
        const Divider(color: kBorder, height: 1),
        Expanded(
          child: displayLines.isEmpty
              ? Center(
                  child: Text(
                    _showErrorsOnly ? 'No errors found' : 'No output',
                    style: const TextStyle(color: kTextMuted, fontSize: 11),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        for (var i = 0; i < displayLines.length; i++) ...[
                          if (i > 0) const TextSpan(text: '\n'),
                          _lineSpan(displayLines[i]),
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
    final isError = line.contains(RegExp(r'error|failed|denied', caseSensitive: false));
    final isWarning = line.contains(RegExp(r'warning', caseSensitive: false));
    final color = isError
        ? kDangerRed
        : isWarning
            ? kAccentAmber
            : kTextSecondary;
    return TextSpan(text: line, style: TextStyle(color: color));
  }

  Widget _buildHeader(bool hasErrors, int errorCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Icon(
            hasErrors ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: hasErrors ? kDangerRed : kSuccessGreen,
          ),
          const SizedBox(width: 6),
          Text(
            widget.environment.name,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (hasErrors)
            GestureDetector(
              onTap: () => setState(() => _showErrorsOnly = !_showErrorsOnly),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _showErrorsOnly
                      ? kDangerRed.withValues(alpha: 0.25)
                      : kDangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _showErrorsOnly
                        ? kDangerRed
                        : kDangerRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$errorCount ${errorCount == 1 ? 'error' : 'errors'}',
                  style: const TextStyle(
                    color: kDangerRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
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
}
