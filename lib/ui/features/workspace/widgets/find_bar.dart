import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.currentMatch,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchCount;
  final int currentMatch;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
              style: const TextStyle(color: kTextPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 28,
                ),
                hintText: 'Buscar en archivo...',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1C2028),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kAccentBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kGlassHighlight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$currentMatch / $matchCount',
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _FindIconButton(
            tooltip: 'Previous match',
            onPressed: onPrevious,
            icon: Icons.keyboard_arrow_up,
          ),
          _FindIconButton(
            tooltip: 'Next match',
            onPressed: onNext,
            icon: Icons.keyboard_arrow_down,
          ),
          const Spacer(),
          _FindIconButton(
            tooltip: 'Close find',
            onPressed: onClose,
            icon: Icons.close,
          ),
        ],
      ),
    );
  }
}

class _FindIconButton extends StatelessWidget {
  const _FindIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: kTextSecondary,
      hoverColor: kGlassHighlight,
      splashRadius: 14,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
    );
  }
}
