import 'package:flutter/widgets.dart';

class EnvironmentKind {
  const EnvironmentKind({
    required this.id,
    required this.name,
    required this.description,
    required this.extension,
    required this.icon,
    required this.sample,
  });

  final String id;
  final String name;
  final String description;
  final String extension;
  final IconData icon;
  final String sample;
}
