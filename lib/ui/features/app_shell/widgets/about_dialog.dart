import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisk/data/services/update_service.dart';
import 'package:whisk/data/services/updater_config.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class AboutDialog extends StatefulWidget {
  const AboutDialog({super.key});

  @override
  State<AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<AboutDialog> {
  String _version = '...';
  UpdateInfo? _updateInfo;
  bool _checking = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final pubspecFile = File('pubspec.yaml');
      if (await pubspecFile.exists()) {
        final content = pubspecFile.readAsStringSync();
        final versionMatch = RegExp(r'version:\s*(\S+)').firstMatch(content);
        final version = versionMatch?.group(1)?.split('+').first ?? '0.0.0';
        setState(() => _version = version);
      }
    } catch (_) {
      setState(() => _version = '0.0.0');
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _status = '';
      _updateInfo = null;
    });

    final config = await UpdaterConfig.load();
    final service = UpdateService(
      repoOwner: config.repoOwner,
      repoName: config.repoName,
    );
    final update = await service.checkForUpdate(_version);
    if (!mounted) return;

    setState(() {
      _checking = false;
      if (update != null) {
        _updateInfo = update;
        _status = 'Version ${update.version} is available';
      } else {
        _status = 'You are up to date';
      }
    });
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/whisk_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Whisk',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version $_version',
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checking ? null : _checkForUpdates,
              icon: _checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(_checking ? 'Checking...' : 'Check for updates'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextSecondary,
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(
                color: _updateInfo != null ? kAccentBlue : kTextMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (_updateInfo != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final url = _updateInfo!.downloadUrl ?? _updateInfo!.releaseUrl;
                  if (url != null) await launchUrl(Uri.parse(url));
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download update'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: kTextMuted)),
        ),
      ],
    );
  }
}
