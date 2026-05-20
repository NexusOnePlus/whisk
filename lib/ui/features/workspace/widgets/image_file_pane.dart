import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whisk/domain/models/whisk_file.dart';
import 'package:whisk/ui/core/glass_panel.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class ImageFilePane extends StatefulWidget {
  const ImageFilePane({super.key, required this.file});

  final WhiskFile file;

  @override
  State<ImageFilePane> createState() => _ImageFilePaneState();
}

class _ImageFilePaneState extends State<ImageFilePane> {
  final TransformationController _transformationController =
      TransformationController();
  int? _width;
  int? _height;
  int _fileSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadFileMetadata();
  }

  @override
  void didUpdateWidget(covariant ImageFilePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadFileMetadata();
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _loadFileMetadata() {
    final file = File(widget.file.path);
    if (file.existsSync()) {
      _fileSizeBytes = file.lengthSync();
      final imageProvider = FileImage(file);
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _width = info.image.width;
              _height = info.image.height;
            });
          }
        }),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAppBlack,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              maxScale: 5.0,
              minScale: 0.1,
              child: Center(
                child: Hero(
                  tag: widget.file.path,
                  child: Image.file(
                    File(widget.file.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 20,
            right: 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GlassPanel(
                borderRadius: 16,
                opacity: 0.8,
                blur: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: kAccentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.file.name,
                              style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_width != null && _height != null ? "$_width × $_height • " : ""}${_formatFileSize(_fileSizeBytes)}',
                              style: const TextStyle(
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Reset Zoom',
                        icon: const Icon(Icons.zoom_out_map, size: 16),
                        color: kTextSecondary,
                        onPressed: () {
                          setState(() {
                            _transformationController.value =
                                Matrix4.identity();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
