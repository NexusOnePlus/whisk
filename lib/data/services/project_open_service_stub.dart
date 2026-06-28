import 'dart:io';
import 'package:whisk/domain/models/whisk_project.dart';

class ProjectOpenService {
  const ProjectOpenService();

  Future<WhiskProject?> pickProject() async => null;

  Future<WhiskProject?> pickProjectFromPath(String rootPath) async => null;

  Future<List<File>> listDirectoryFiles(String path) async => const [];

  Future<List<FileSystemEntity>> listDirectoryEntries(String path) async => const [];

  String extensionOf(String path) => '';
}
