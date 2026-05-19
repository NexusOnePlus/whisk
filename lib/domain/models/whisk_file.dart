class WhiskFile {
  const WhiskFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.content,
    this.isDirty = false,
  });

  final String path;
  final String name;
  final String extension;
  final String content;
  final bool isDirty;

  WhiskFile copyWith({
    String? path,
    String? name,
    String? extension,
    String? content,
    bool? isDirty,
  }) {
    return WhiskFile(
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
