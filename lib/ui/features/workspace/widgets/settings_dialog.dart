import 'package:flutter/material.dart';
import 'package:whisk/data/services/settings_service.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _nameController;
  final _service = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _service.profileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kAccentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings, color: kAccentBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Settings',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Display name used in collaboration sessions',
              style: TextStyle(color: kTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: kTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                filled: true,
                fillColor: kGlassHighlight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kAccentBlue),
                ),
              ),
              onSubmitted: (_) => _saveProfileName(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: kTextMuted)),
        ),
        FilledButton(
          onPressed: _saveProfileName,
          style: FilledButton.styleFrom(
            backgroundColor: kAccentBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveProfileName() {
    _service.setProfileName(_nameController.text.trim());
    Navigator.of(context).pop();
  }
}
