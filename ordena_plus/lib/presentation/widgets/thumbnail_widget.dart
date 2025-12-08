import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class ThumbnailWidget extends StatefulWidget {
  final String mediaId;
  final String? path; // Optional path for fallback
  final double size;
  final BoxFit fit;

  const ThumbnailWidget({
    super.key,
    required this.mediaId,
    this.path,
    this.size = 200,
    this.fit = BoxFit.cover,
  });

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  Uint8List? _thumbnailData;
  File? _fileImage;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant ThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId || oldWidget.path != widget.path) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailData = null;
      _fileImage = null;
    });

    try {
      // 1. Try fetching from PhotoManager (fastest for gallery items)
      final asset = await AssetEntity.fromId(widget.mediaId);

      if (asset != null) {
        final data = await asset.thumbnailDataWithSize(
          ThumbnailSize.square(widget.size.toInt()),
        );
        if (mounted && data != null) {
          setState(() {
            _thumbnailData = data;
            _isLoading = false;
          });
          return;
        }
      }

      // 2. Fallback: Load from file path if provided
      if (widget.path != null) {
        final file = File(widget.path!);
        if (await file.exists()) {
          if (mounted) {
            setState(() {
              _fileImage = file;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 3. Last Resort: Error
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || (_thumbnailData == null && _fileImage == null)) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    if (_thumbnailData != null) {
      return Image.memory(
        _thumbnailData!,
        fit: widget.fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
      );
    }

    return Image.file(
      _fileImage!,
      fit: widget.fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
