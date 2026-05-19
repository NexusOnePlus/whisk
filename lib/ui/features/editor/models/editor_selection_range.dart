class EditorSelectionRange {
  const EditorSelectionRange({
    required this.baseOffset,
    required this.extentOffset,
  });

  final int baseOffset;
  final int extentOffset;

  int get start => baseOffset < extentOffset ? baseOffset : extentOffset;
  int get end => baseOffset > extentOffset ? baseOffset : extentOffset;
  bool get isCollapsed => baseOffset == extentOffset;
}
