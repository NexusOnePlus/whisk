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
      height: 42,
      padding: const EdgeInsets.fromLTRB(14, 4, 16, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
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
                prefixIcon: const Icon(Icons.search, size: 16),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 28,
                ),
                hintText: 'Find in file',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF22262E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: kAccentBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$currentMatch / $matchCount',
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Previous match',
            onPressed: onPrevious,
            icon: const Icon(Icons.keyboard_arrow_up),
            color: kTextSecondary,
            iconSize: 18,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: onNext,
            icon: const Icon(Icons.keyboard_arrow_down),
            color: kTextSecondary,
            iconSize: 18,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Close find',
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: kTextSecondary,
            iconSize: 17,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
