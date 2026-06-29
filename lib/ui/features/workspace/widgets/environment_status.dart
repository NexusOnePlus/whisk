import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

enum _EngineState { unknown, available, unavailable, downloading }

class EnvironmentStatus extends StatefulWidget {
  const EnvironmentStatus({super.key});

  @override
  State<EnvironmentStatus> createState() => _EnvironmentStatusState();
}

class _EnvironmentStatusState extends State<EnvironmentStatus> {
  final _catalog = const EnvironmentCatalog();
  final Map<String, _EngineState> _states = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _logs = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    for (final env in _catalog.listEnvironments()) {
      _states[env.id] = _EngineState.unknown;
    }
    _checkAll();
  }

  Future<void> _checkAll() async {
    for (final env in _catalog.listEnvironments()) {
      if (env.id == 'latex' || env.id == 'typst') {
        await _checkEngine(env.id);
      } else {
        setState(() => _states[env.id] = _EngineState.available);
      }
    }
  }

  Future<void> _checkEngine(String id) async {
    final exe = id == 'latex' ? 'tectonic' : 'tinymist';
    final path = await _bundledPath(exe);
    if (await File(path).exists()) {
      setState(() => _states[id] = _EngineState.available);
      return;
    }
    final inPath = await _resolveFromPath(exe);
    setState(() => _states[id] = inPath != null
        ? _EngineState.available
        : _EngineState.unavailable);
  }

  Future<String> _bundledPath(String exe) async {
    final support = await getApplicationSupportDirectory();
    return [
      support.path,
      'engines',
      exe,
      Platform.isWindows ? '$exe.exe' : exe,
    ].join(Platform.pathSeparator);
  }

  Future<String?> _resolveFromPath(String executable) async {
    final command = Platform.isWindows ? 'where.exe' : 'which';
    try {
      final result = await Process.run(command, [executable]);
      if (result.exitCode != 0) return null;
      final firstLine = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .firstOrNull;
      return firstLine?.trim();
    } on ProcessException {
      return null;
    }
  }

  String _nameFor(String id) {
    if (id == 'latex') return 'Tectonic';
    if (id == 'typst') return 'Typst';
    return id;
  }

  String _apiFor(String id) {
    if (id == 'latex') {
      return 'https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest';
    }
    return 'https://api.github.com/repos/Myriad-Dreamin/tinymist/releases/latest';
  }

  String _executableName(String id) {
    final exe = id == 'latex' ? 'tectonic' : 'tinymist';
    return Platform.isWindows ? '$exe.exe' : exe;
  }

  Future<void> _downloadEngine(String id) async {
    setState(() {
      _states[id] = _EngineState.downloading;
      _progress[id] = 0;
      _errors.remove(id);
    });

    try {
      final exe = id == 'latex' ? 'tectonic' : 'tinymist';
      final toPath = await _bundledPath(exe);

      final log = StringBuffer('${_nameFor(id)} was not found locally.\n');

      final release = await http.get(
        Uri.parse(_apiFor(id)),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Whisk document renderer',
        },
      );
      if (release.statusCode < 200 || release.statusCode >= 300) {
        setState(() {
          _states[id] = _EngineState.unavailable;
          _errors[id] = 'Could not query releases: HTTP ${release.statusCode}';
        });
        return;
      }

      final json = jsonDecode(release.body) as Map<String, dynamic>;
      final assets = (json['assets'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final asset = assets.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.startsWith('tinymist-') &&
            name.endsWith('.zip') &&
            name.contains('x86_64-pc-windows-msvc') &&
            !name.contains('viewer') &&
            !name.contains('docs-tool');
      }).firstOrNull;

      final downloadUrl = asset?['browser_download_url']?.toString();
      if (downloadUrl == null || downloadUrl.isEmpty) {
        setState(() {
          _states[id] = _EngineState.unavailable;
          _errors[id] = 'Could not find Windows x86_64 ZIP in latest release';
        });
        return;
      }

      log.writeln('Downloading ${asset!['name']}');
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(downloadUrl));
        request.headers['User-Agent'] = 'Whisk document renderer';
        final response = await client.send(request);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          setState(() {
            _states[id] = _EngineState.unavailable;
            _errors[id] = 'Download failed: HTTP ${response.statusCode}';
          });
          return;
        }

        final total = response.contentLength ?? 0;
        final chunks = <List<int>>[];
        var received = 0;

        await for (final chunk in response.stream) {
          chunks.add(chunk);
          received += chunk.length;
          if (total > 0 && mounted) {
            setState(() => _progress[id] = received / total);
          }
        }

        final archiveBytes = <int>[];
        for (final chunk in chunks) {
          archiveBytes.addAll(chunk);
        }

        final archive = ZipDecoder().decodeBytes(archiveBytes);
        final executable = archive.files
            .where((file) =>
                file.isFile && file.name.endsWith(_executableName(id)))
            .firstOrNull;
        if (executable == null) {
          setState(() {
            _states[id] = _EngineState.unavailable;
            _errors[id] = 'Downloaded archive did not contain ${_executableName(id)}';
          });
          return;
        }

        final output = File(toPath);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(executable.content as List<int>);

        log.writeln('Installed ${_nameFor(id)} at ${output.path}.');
        _logs[id] = log.toString();

        if (mounted) {
          setState(() {
            _states[id] = _EngineState.available;
            _progress[id] = 1;
          });
        }
      } finally {
        client.close();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _states[id] = _EngineState.unavailable;
          _errors[id] = 'Engine setup failed: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final environments = _catalog.listEnvironments();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Environments',
          style: TextStyle(
            color: kTextMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        for (final env in environments) ...[
          _EnvironmentTile(
            icon: env.icon,
            name: env.name,
            description: env.description,
            state: _states[env.id] ?? _EngineState.unknown,
            progress: _progress[env.id],
            error: _errors[env.id],
            log: _logs[env.id],
            onInstall: (env.id == 'latex' || env.id == 'typst')
                ? () => _downloadEngine(env.id)
                : null,
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _EnvironmentTile extends StatelessWidget {
  const _EnvironmentTile({
    required this.icon,
    required this.name,
    required this.description,
    required this.state,
    this.progress,
    this.error,
    this.log,
    this.onInstall,
  });

  final IconData icon;
  final String name;
  final String description;
  final _EngineState state;
  final double? progress;
  final String? error;
  final String? log;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kGlassHighlight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kAccentBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StateBadge(state: state),
            ],
          ),
          if (state == _EngineState.downloading && progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: kBorder,
                valueColor: const AlwaysStoppedAnimation(kAccentBlue),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress! * 100).toInt()}%',
              style: const TextStyle(color: kTextMuted, fontSize: 10),
            ),
          ],
          if (state == _EngineState.unavailable && onInstall != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInstall,
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Install', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextSecondary,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: const TextStyle(color: kDangerRed, fontSize: 10),
            ),
          ],
          if (log != null) ...[
            const SizedBox(height: 6),
            Text(
              log!,
              style: const TextStyle(color: kTextMuted, fontSize: 9),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final _EngineState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      _EngineState.available => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kSuccessGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kSuccessGreen.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: kSuccessGreen),
            SizedBox(width: 4),
            Text(
              'Ready',
              style: TextStyle(
                color: kSuccessGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _EngineState.unavailable => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kDangerRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kDangerRed.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 10, color: kDangerRed),
            SizedBox(width: 4),
            Text(
              'Missing',
              style: TextStyle(
                color: kDangerRed,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _EngineState.downloading => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kAccentBlue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kAccentBlue.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            SizedBox(width: 4),
            Text(
              'Installing',
              style: TextStyle(
                color: kAccentBlue,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      _EngineState.unknown => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kTextMuted.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Checking',
          style: TextStyle(
            color: kTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    };
  }
}
