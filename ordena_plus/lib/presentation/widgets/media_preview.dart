import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:video_player/video_player.dart';

class MediaPreview extends StatefulWidget {
  final MediaItem mediaItem;

  const MediaPreview({super.key, required this.mediaItem});

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void didUpdateWidget(MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.id != widget.mediaItem.id) {
      _disposeVideo();
      _initializeMedia();
    }
  }

  void _initializeMedia() {
    if (widget.mediaItem.type == MediaType.video) {
      _videoController = VideoPlayerController.file(File(widget.mediaItem.path))
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItem.type == MediaType.photo) {
      return Image.file(
        File(widget.mediaItem.path),
        fit: BoxFit.contain,
        key: ValueKey(widget.mediaItem.path),
      );
    } else {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
  }
}
