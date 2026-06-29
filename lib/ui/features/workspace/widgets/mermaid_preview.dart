import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class MermaidDiagram extends StatelessWidget {
  const MermaidDiagram({
    super.key,
    required this.code,
    this.style,
  });

  final String code;
  final MermaidStyle? style;

  @override
  Widget build(BuildContext context) {
    final isDark = style?.isDark ?? true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2228) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: isDark ? kAccentBlue : Colors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                'Mermaid diagram',
                style: TextStyle(
                  color: isDark ? kTextMuted : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? kAppBlack : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              code,
              style: TextStyle(
                color: isDark ? kTextSecondary : Colors.grey[800],
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MermaidStyle {
  const MermaidStyle._({required this.isDark});

  static const dark = MermaidStyle._(isDark: true);
  static const light = MermaidStyle._(isDark: false);

  final bool isDark;
}
