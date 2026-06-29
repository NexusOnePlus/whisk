import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class EngineProvisionService {
  const EngineProvisionService();

  static const _tectonicReleaseApi =
      'https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest';
  static const _typstReleaseApi =
      'https://api.github.com/repos/Myriad-Dreamin/tinymist/releases/latest';

  Future<EngineResolution> ensureTectonic() async {
    final bundled = await _bundledTectonicPath();
    if (await File(bundled).exists()) {
      return EngineResolution.available(executablePath: bundled);
    }

    final pathEngine = await _resolveFromPath('tectonic');
    if (pathEngine != null) {
      return EngineResolution.available(executablePath: pathEngine);
    }

    return _downloadTectonic(toPath: bundled);
  }

  Future<String> _bundledTectonicPath() async {
    final support = await getApplicationSupportDirectory();
    return [
      support.path,
      'engines',
      'tectonic',
      Platform.isWindows ? 'tectonic.exe' : 'tectonic',
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

  Future<EngineResolution> _downloadTectonic({required String toPath}) async {
    if (!Platform.isWindows) {
      return const EngineResolution.unavailable(
        'Auto-download is currently wired for Windows only. Install tectonic in PATH on this platform.',
      );
    }

    final log = StringBuffer('Tectonic was not found locally.\n');
    try {
      final release = await http.get(
        Uri.parse(_tectonicReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Whisk document renderer',
        },
      );
      if (release.statusCode < 200 || release.statusCode >= 300) {
        return EngineResolution.unavailable(
          '${log}Could not query Tectonic releases: HTTP ${release.statusCode}.',
        );
      }

      final json = jsonDecode(release.body) as Map<String, dynamic>;
      final assets = (json['assets'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final asset = assets.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.endsWith('.zip') && name.contains('x86_64-pc-windows-msvc');
      }).firstOrNull;

      final downloadUrl = asset?['browser_download_url']?.toString();
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return EngineResolution.unavailable(
          '${log}Could not find a Windows x86_64 Tectonic ZIP in the latest release.',
        );
      }

      log.writeln('Downloading ${asset!['name']}');
      final archiveResponse = await http.get(
        Uri.parse(downloadUrl),
        headers: const {'User-Agent': 'Whisk document renderer'},
      );
      if (archiveResponse.statusCode < 200 ||
          archiveResponse.statusCode >= 300) {
        return EngineResolution.unavailable(
          '${log}Download failed: HTTP ${archiveResponse.statusCode}.',
        );
      }

      final archive = ZipDecoder().decodeBytes(archiveResponse.bodyBytes);
      final executable = archive.files
          .where((file) => file.isFile && file.name.endsWith('tectonic.exe'))
          .firstOrNull;
      if (executable == null) {
        return EngineResolution.unavailable(
          '${log}Downloaded archive did not contain tectonic.exe.',
        );
      }

      final output = File(toPath);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(executable.content as List<int>);

      return EngineResolution.available(
        executablePath: output.path,
        log: '${log}Installed Tectonic at ${output.path}.',
        wasProvisioned: true,
      );
    } on Object catch (error) {
      return EngineResolution.unavailable('${log}Engine setup failed: $error');
    }
  }

  Future<EngineResolution> ensureTypst() async {
    final bundled = await _bundledTinymistPath();
    if (await File(bundled).exists()) {
      return EngineResolution.available(executablePath: bundled);
    }

    final pathEngine = await _resolveFromPath('tinymist');
    if (pathEngine != null) {
      return EngineResolution.available(executablePath: pathEngine);
    }

    return _downloadTinymist(toPath: bundled);
  }

  Future<String> _bundledTinymistPath() async {
    final support = await getApplicationSupportDirectory();
    return [
      support.path,
      'engines',
      'tinymist',
      Platform.isWindows ? 'tinymist.exe' : 'tinymist',
    ].join(Platform.pathSeparator);
  }

  Future<EngineResolution> _downloadTinymist({required String toPath}) async {
    if (!Platform.isWindows) {
      return const EngineResolution.unavailable(
        'Auto-download is currently wired for Windows only. Install tinymist in PATH on this platform.',
      );
    }

      final log = StringBuffer('Tinymist (Typst) was not found locally.\n');
      try {
        final release = await http.get(
          Uri.parse(_typstReleaseApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Whisk document renderer',
          },
        );
        if (release.statusCode < 200 || release.statusCode >= 300) {
          return EngineResolution.unavailable(
            '${log}Could not query Tinymist releases: HTTP ${release.statusCode}.',
          );
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
        return EngineResolution.unavailable(
          '${log}Could not find a Windows x86_64 Tinymist ZIP in the latest release.',
        );
      }

      log.writeln('Downloading ${asset!['name']}');
      final archiveResponse = await http.get(
        Uri.parse(downloadUrl),
        headers: const {'User-Agent': 'Whisk document renderer'},
      );
      if (archiveResponse.statusCode < 200 ||
          archiveResponse.statusCode >= 300) {
        return EngineResolution.unavailable(
          '${log}Download failed: HTTP ${archiveResponse.statusCode}.',
        );
      }

      final archive = ZipDecoder().decodeBytes(archiveResponse.bodyBytes);
      final executable = archive.files
          .where((file) =>
              file.isFile &&
              file.name.replaceAll('\\', '/').endsWith('tinymist.exe'))
          .firstOrNull;
      if (executable == null) {
        return EngineResolution.unavailable(
          '${log}Downloaded archive did not contain tinymist.exe.',
        );
      }

      final output = File(toPath);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(executable.content as List<int>);

      return EngineResolution.available(
        executablePath: output.path,
        log: '${log}Installed Tinymist at ${output.path}.',
        wasProvisioned: true,
      );
    } on Object catch (error) {
      return EngineResolution.unavailable('${log}Engine setup failed: $error');
    }
  }
}

class EngineResolution {
  const EngineResolution._({
    required this.available,
    required this.executablePath,
    required this.log,
    required this.wasProvisioned,
  });

  const EngineResolution.available({
    required String executablePath,
    String log = '',
    bool wasProvisioned = false,
  }) : this._(
         available: true,
         executablePath: executablePath,
         log: log,
         wasProvisioned: wasProvisioned,
       );

  const EngineResolution.unavailable(String log)
    : this._(
        available: false,
        executablePath: null,
        log: log,
        wasProvisioned: false,
      );

  final bool available;
  final String? executablePath;
  final String log;
  final bool wasProvisioned;
}
