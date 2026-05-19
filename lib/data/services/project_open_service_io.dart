import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class ProjectOpenService {
  const ProjectOpenService();

  Future<WhiskFile?> pickLatexProject() async {
    final rootPath = await getDirectoryPath(
      confirmButtonText: 'Open LaTeX project',
    );
    if (rootPath == null) return null;

    final root = Directory(rootPath);
    final source = await _findLatexEntry(root);
    if (source == null) return null;

    final content = await source.readAsString();
    return WhiskFile(
      path: source.path,
      name: source.uri.pathSegments.last,
      extension: '.tex',
      content: content,
      projectRoot: root.path,
    );
  }

  Future<File?> _findLatexEntry(Directory root) async {
    final main = File('${root.path}${Platform.pathSeparator}main.tex');
    if (await main.exists()) return main;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.tex')) {
        return entity;
      }
    }

    return null;
  }
}
