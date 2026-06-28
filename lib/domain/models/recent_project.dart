class RecentProject {
  const RecentProject({
    required this.path,
    required this.name,
    required this.type,
    required this.lastOpened,
  });

  final String path;
  final String name;
  final String type;
  final int lastOpened;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'type': type,
        'lastOpened': lastOpened,
      };

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        path: json['path'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        lastOpened: json['lastOpened'] as int,
      );
}
