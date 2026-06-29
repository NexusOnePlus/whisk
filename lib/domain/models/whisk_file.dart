class WhiskFile {
  static const empty = WhiskFile(
    path: '',
    name: '',
    extension: '',
    content: '',
  );

  const WhiskFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.content,
    this.projectRoot,
    this.isDirty = false,
    this.isDirectory = false,
  });

  final String path;
  final String name;
  final String extension;
  final String content;
  final String? projectRoot;
  final bool isDirty;
  final bool isDirectory;

  bool get isImage => const {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
  }.contains(extension.toLowerCase());

  bool get isPdf => extension.toLowerCase() == '.pdf';

  WhiskFile copyWith({
    String? path,
    String? name,
    String? extension,
    String? content,
    String? projectRoot,
    bool? isDirty,
    bool? isDirectory,
  }) {
    return WhiskFile(
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      content: content ?? this.content,
      projectRoot: projectRoot ?? this.projectRoot,
      isDirty: isDirty ?? this.isDirty,
      isDirectory: isDirectory ?? this.isDirectory,
    );
  }
}
