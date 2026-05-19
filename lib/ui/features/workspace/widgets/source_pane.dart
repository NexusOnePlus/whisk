import 'package:flutter/material.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class SourcePane extends StatelessWidget {
  const SourcePane({
    super.key,
    required this.environment,
    required this.controller,
    required this.onChanged,
  });

  final EnvironmentKind environment;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAppBlack,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.45,
          color: kTextPrimary,
        ),
        decoration: const InputDecoration(
          filled: true,
          fillColor: kAppBlack,
          border: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(22, 18, 22, 22),
        ),
      ),
    );
  }
}
