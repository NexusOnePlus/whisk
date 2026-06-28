class RecentProject {
  const RecentProject({
    required this.path,
    required this.name,
    required this.type,
    required this.lastOpened,
    this.lastFilePath,
  });

  final String path;
  final String name;
  final String type;
  final int lastOpened;
  final String? lastFilePath;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'type': type,
        'lastOpened': lastOpened,
        if (lastFilePath != null) 'lastFilePath': lastFilePath,
      };

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        path: json['path'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        lastOpened: json['lastOpened'] as int,
        lastFilePath: json['lastFilePath'] as String?,
      );

  RecentProject copyWith({
    String? path,
    String? name,
    String? type,
    int? lastOpened,
    String? lastFilePath,
  }) {
    return RecentProject(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      lastOpened: lastOpened ?? this.lastOpened,
      lastFilePath: lastFilePath ?? this.lastFilePath,
    );
  }
}
