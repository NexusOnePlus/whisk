import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class PreviewPane extends StatelessWidget {
  const PreviewPane({super.key, required this.environment});

  final EnvironmentKind environment;

  @override
  Widget build(BuildContext context) {
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
              const _PreviewPill(label: 'idle'),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Render'),
                style: TextButton.styleFrom(
                  foregroundColor: kAppBlack,
                  backgroundColor: kTextPrimary,
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPanel,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
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
                    '${environment.name} engine',
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Renderer adapter pending for ${environment.extension} files.',
                    style: const TextStyle(color: kTextSecondary),
                  ),
                  const SizedBox(height: 24),
                  const _PreviewStatusGrid(),
                  const Spacer(),
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
            ),
          ),
        ],
      ),
    );
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
  const _PreviewStatusGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _PreviewMetric(label: 'Diagnostics', value: '0'),
        _PreviewMetric(label: 'Last render', value: '--'),
        _PreviewMetric(label: 'Pages', value: '--'),
      ],
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
