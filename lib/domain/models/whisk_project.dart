import 'package:whisk/domain/models/whisk_file.dart';

class WhiskProject {
  const WhiskProject({
    required this.rootPath,
    required this.files,
    required this.entryFile,
  });

  final String rootPath;
  final List<WhiskFile> files;
  final WhiskFile entryFile;
}
