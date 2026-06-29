import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

import 'dart:developer' as dev;

class UpdaterConfig {
  const UpdaterConfig({
    required this.repoOwner,
    required this.repoName,
    required this.checkOnStartup,
    required this.showReleaseNotes,
  });

  final String repoOwner;
  final String repoName;
  final bool checkOnStartup;
  final bool showReleaseNotes;

  static Future<UpdaterConfig> load() async {
    if (kIsWeb) {
      return const UpdaterConfig(
        repoOwner: 'NexusOnePlus',
        repoName: 'whisk',
        checkOnStartup: true,
        showReleaseNotes: true,
      );
    }

    try {
      final file = File('updater.yaml');
      if (await file.exists()) {
        final content = await file.readAsString();
        final yaml = loadYaml(content) as Map;
        final app = yaml['app'] as Map? ?? {};
        final updater = yaml['updater'] as Map? ?? {};
        return UpdaterConfig(
          repoOwner: app['repo_owner'] ?? 'NexusOnePlus',
          repoName: app['repo_name'] ?? 'whisk',
          checkOnStartup: updater['check_on_startup'] ?? true,
          showReleaseNotes: updater['show_release_notes'] ?? true,
        );
      }
    } catch (e) {
      dev.log('Failed to load updater config: $e', name: 'UpdaterConfig');
    }

    return const UpdaterConfig(
      repoOwner: 'NexusOnePlus',
      repoName: 'whisk',
      checkOnStartup: true,
      showReleaseNotes: true,
    );
  }
}
