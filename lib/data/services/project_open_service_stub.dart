import 'dart:io';
import 'package:whisk/domain/models/whisk_project.dart';

class ProjectOpenService {
  const ProjectOpenService();

  Future<WhiskProject?> pickLatexProject() async => null;

  Future<List<File>> listDirectoryFiles(String path) async => const [];

  String extensionOf(String path) => '';
}
