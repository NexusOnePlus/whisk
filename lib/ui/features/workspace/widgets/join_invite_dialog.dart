import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class JoinInviteDialog extends StatefulWidget {
  const JoinInviteDialog({super.key});

  @override
  State<JoinInviteDialog> createState() => _JoinInviteDialogState();
}

class _JoinInviteDialogState extends State<JoinInviteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF22262E),
      title: const Text(
        'Join collaboration',
        style: TextStyle(color: kTextPrimary),
      ),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            labelText: 'Invite',
            labelStyle: TextStyle(color: kTextMuted),
            hintText: 'Paste collaboration invite',
            hintStyle: TextStyle(color: kTextMuted),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: kTextMuted),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final invite = _controller.text.trim();
            if (invite.isEmpty) return;
            Navigator.of(context).pop(invite);
          },
          child: const Text('Join'),
        ),
      ],
    );
  }
}
