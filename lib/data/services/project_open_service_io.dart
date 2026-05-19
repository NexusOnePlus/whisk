import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/domain/models/whisk_project.dart';

class ProjectOpenService {
  const ProjectOpenService();

  Future<WhiskProject?> pickLatexProject() async {
    final rootPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Open LaTeX project',
    );
    if (rootPath == null) return null;

    final root = Directory(rootPath);
    final files = await _listProjectFiles(root);
    final source = _findLatexEntry(root, files);
    if (source == null) return null;

    final content = await source.readAsString();
    final entryFile = WhiskFile(
      path: source.path,
      name: source.uri.pathSegments.last,
      extension: '.tex',
      content: content,
      projectRoot: root.path,
    );

    return WhiskProject(
      rootPath: root.path,
      files: files
          .map(
            (file) => WhiskFile(
              path: file.path,
              name: file.uri.pathSegments.last,
              extension: _extensionOf(file.path),
              content: file.path == source.path ? content : '',
              projectRoot: root.path,
            ),
          )
          .toList(growable: false),
      entryFile: entryFile,
    );
  }

  File? _findLatexEntry(Directory root, List<File> files) {
    final main = File('${root.path}${Platform.pathSeparator}main.tex');
    if (files.any((file) => file.path == main.path)) return main;

    return files
        .where((file) => file.path.toLowerCase().endsWith('.tex'))
        .firstOrNull;
  }

  Future<List<File>> _listProjectFiles(Directory root) async {
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (_isIgnoredPath(root.path, entity.path)) continue;
      if (!_isRenderableProjectFile(entity.path)) continue;
      files.add(entity);
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  bool _isIgnoredPath(String rootPath, String path) {
    final relative = path.substring(rootPath.length);
    return relative.contains(
          '${Platform.pathSeparator}.git${Platform.pathSeparator}',
        ) ||
        relative.contains(
          '${Platform.pathSeparator}.whisk${Platform.pathSeparator}',
        ) ||
        relative.contains(
          '${Platform.pathSeparator}build${Platform.pathSeparator}',
        );
  }

  bool _isRenderableProjectFile(String path) {
    final extension = _extensionOf(path);
    return const {
      '.tex',
      '.bib',
      '.sty',
      '.cls',
      '.typ',
      '.md',
      '.mmd',
    }.contains(extension);
  }

  String _extensionOf(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final index = name.lastIndexOf('.');
    if (index < 0) return '';
    return name.substring(index).toLowerCase();
  }
}
