import 'dart:io';

import 'package:yaml/yaml.dart';

const _currentConfigVersion = 1;

class WorkspaceConfig {
  const WorkspaceConfig._({
    required this.latexEngine,
    required this.typstEngine,
    required this.autoRender,
    required this.debounceMs,
  });

  final String latexEngine;
  final String typstEngine;
  final bool autoRender;
  final int debounceMs;

  static const defaultConfig = WorkspaceConfig._(
    latexEngine: 'auto',
    typstEngine: 'auto',
    autoRender: true,
    debounceMs: 500,
  );

  static Future<WorkspaceConfig> load(String projectRoot) async {
    final file = File(
      '$projectRoot${Platform.pathSeparator}.whisk${Platform.pathSeparator}config.yaml',
    );
    if (!await file.exists()) return defaultConfig;

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! Map) return defaultConfig;
      final build = yaml['build'] as Map? ?? {};
      final latex = build['latex'] as Map? ?? {};
      final typst = build['typst'] as Map? ?? {};
      final preview = yaml['preview'] as Map? ?? {};
      return WorkspaceConfig._(
        latexEngine: latex['engine'] as String? ?? 'auto',
        typstEngine: typst['engine'] as String? ?? 'auto',
        autoRender: preview['auto_render'] as bool? ?? true,
        debounceMs: (preview['debounce_ms'] as num?)?.toInt() ?? 500,
      );
    } catch (_) {
      return defaultConfig;
    }
  }

  static Future<void> ensureDefaults(String projectRoot) async {
    final dir = Directory('$projectRoot${Platform.pathSeparator}.whisk');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}${Platform.pathSeparator}config.yaml');
    if (await file.exists()) {
      final needsUpdate = await _checkNeedsUpdate(file);
      if (!needsUpdate) return;
    }

    await file.writeAsString(_defaultConfigYaml());
  }

  static Future<bool> _checkNeedsUpdate(File file) async {
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      if (yaml is! Map) return true;
      final version = yaml['version'] as int? ?? 0;
      return version < _currentConfigVersion;
    } catch (_) {
      return true;
    }
  }

  static String _defaultConfigYaml() {
    return '# Whisk workspace configuration\n'
        'version: $_currentConfigVersion\n'
        '\n'
        'build:\n'
        '  latex:\n'
        '    engine: auto\n'
        '    output_dir: .whisk/build/latex\n'
        '    cache_dir: .whisk/cache\n'
        '  typst:\n'
        '    engine: auto\n'
        '    output_dir: .whisk/build/typst\n'
        '    cache_dir: .whisk/cache\n'
        '\n'
        'preview:\n'
        '  auto_render: true\n'
        '  debounce_ms: 500\n';
  }
}
