import 'package:flutter/material.dart';

class CollaborationPeer {
  const CollaborationPeer({
    required this.id,
    required this.name,
    required this.color,
    this.cursorOffset,
    this.selectionStart,
    this.selectionEnd,
  });

  final String id;
  final String name;
  final Color color;
  final int? cursorOffset;
  final int? selectionStart;
  final int? selectionEnd;

  CollaborationPeer copyWith({
    String? name,
    Color? color,
    int? cursorOffset,
    int? selectionStart,
    int? selectionEnd,
  }) {
    return CollaborationPeer(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      cursorOffset: cursorOffset ?? this.cursorOffset,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
    );
  }
}
