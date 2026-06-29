import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  UpdateService({
    http.Client? httpClient,
    this.repoOwner = 'YOUR_USERNAME',
    this.repoName = 'whisk',
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String repoOwner;
  final String repoName;

  String get _apiUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await _http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'whisk',
        },
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.replaceFirst(RegExp(r'^v'), '');
      if (version.isEmpty || version == currentVersion) return null;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      String? fileName;
      int? fileSize;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (name.contains('setup') || name.endsWith('.exe')) {
            downloadUrl = asset['browser_download_url'] as String?;
            fileName = name;
            fileSize = asset['size'] as int?;
            break;
          }
        }
      }

      return UpdateInfo(
        version: version,
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        releaseUrl: data['html_url'] as String?,
        body: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<File?> downloadUpdate(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (info.downloadUrl == null) return null;

    final tempDir = await getTemporaryDirectory();
    final fileName = info.fileName ?? 'whisk-setup.exe';
    final file = File('${tempDir.path}/$fileName');

    final request = http.Request('GET', Uri.parse(info.downloadUrl!));
    final response = await _http.send(request);

    if (response.statusCode != 200) return null;

    final contentLength = response.contentLength ?? info.fileSize ?? 0;
    var bytesReceived = 0;

    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesReceived += chunk.length;
      if (contentLength > 0) {
        onProgress?.call(bytesReceived / contentLength);
      }
    }
    await sink.close();

    return file;
  }

  Future<bool> installUpdate(File installerFile) async {
    if (!await installerFile.exists()) return false;

    final result = await Process.run(
      installerFile.path,
      ['/SILENT', '/NORESTART'],
      runInShell: true,
    );
    return result.exitCode == 0;
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.fileName,
    this.fileSize,
    this.releaseUrl,
    this.body,
  });

  final String version;
  final String? downloadUrl;
  final String? fileName;
  final int? fileSize;
  final String? releaseUrl;
  final String? body;
}
