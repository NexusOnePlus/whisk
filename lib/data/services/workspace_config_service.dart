import 'dart:io';

import 'package:yaml/yaml.dart';

class WorkspaceConfig {
  WorkspaceConfig._();
  static const _fileName = 'config.yaml';
  static const _dirName = '.whisk';

  static Future<void> ensureDefaults(String projectRoot) async {
    final dir = Directory('$projectRoot${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    if (await file.exists()) return;

    await file.writeAsString(_defaultConfig());
  }

  static Future<Map<String, dynamic>> load(String projectRoot) async {
    final file = File(
      '$projectRoot${Platform.pathSeparator}$_dirName${Platform.pathSeparator}$_fileName',
    );
    if (!await file.exists()) return _defaults();

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      if (yaml is Map) return Map<String, dynamic>.from(yaml);
    } catch (_) {}
    return _defaults();
  }

  static Map<String, dynamic> _defaults() => {
    'version': 1,
    'build': {
      'latex': {
        'engine': 'auto',
        'output_dir': '.whisk/build/latex',
        'cache_dir': '.whisk/cache',
      },
      'typst': {
        'engine': 'auto',
        'output_dir': '.whisk/build/typst',
        'cache_dir': '.whisk/cache',
      },
    },
    'preview': {
      'auto_render': true,
      'debounce_ms': 500,
    },
  };

  static String _defaultConfig() {
    final sb = StringBuffer();
    sb.writeln('# Whisk workspace configuration');
    sb.writeln('version: 1');
    sb.writeln('');
    sb.writeln('build:');
    sb.writeln('  latex:');
    sb.writeln('    engine: auto');
    sb.writeln('    output_dir: .whisk/build/latex');
    sb.writeln('    cache_dir: .whisk/cache');
    sb.writeln('  typst:');
    sb.writeln('    engine: auto');
    sb.writeln('    output_dir: .whisk/build/typst');
    sb.writeln('    cache_dir: .whisk/cache');
    sb.writeln('');
    sb.writeln('preview:');
    sb.writeln('  auto_render: true');
    sb.writeln('  debounce_ms: 500');
    return sb.toString();
  }
}
