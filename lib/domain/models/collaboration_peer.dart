import 'package:flutter/material.dart';

class CollaborationPeer {
  const CollaborationPeer({
    required this.id,
    required this.name,
    required this.color,
    required this.filePath,
    this.cursorOffset,
    this.selectionStart,
    this.selectionEnd,
  });

  final String id;
  final String name;
  final Color color;
  final String filePath;
  final int? cursorOffset;
  final int? selectionStart;
  final int? selectionEnd;

  CollaborationPeer copyWith({
    String? id,
    String? name,
    Color? color,
    String? filePath,
    int? cursorOffset,
    int? selectionStart,
    int? selectionEnd,
  }) {
    return CollaborationPeer(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      filePath: filePath ?? this.filePath,
      cursorOffset: cursorOffset ?? this.cursorOffset,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
    );
  }
}
