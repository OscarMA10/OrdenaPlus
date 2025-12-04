import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ordena_plus/domain/models/media_item.dart';
import 'package:video_player/video_player.dart';

class MediaPreview extends StatefulWidget {
  final MediaItem mediaItem;
  final bool enableZoom;

  const MediaPreview({
    super.key,
    required this.mediaItem,
    this.enableZoom = false,
  });

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

  void _togglePlay() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItem.type == MediaType.photo) {
      final image = Image.file(
        File(widget.mediaItem.path),
        fit: BoxFit.contain,
        key: ValueKey(widget.mediaItem.path),
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
          );
        },
      );

      if (widget.enableZoom) {
        return InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: image);
      }
      return image;
    } else {
      if (_videoController != null && _videoController!.value.isInitialized) {
        Widget videoWidget = AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );

        // Add tap to play/pause ONLY if zoom is enabled (Full Screen Mode)
        // This prevents stealing the tap event in Home Screen (Preview Mode)
        if (widget.enableZoom) {
          videoWidget = GestureDetector(onTap: _togglePlay, child: videoWidget);

          videoWidget = InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: videoWidget,
          );
        }

        return videoWidget;
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
  }
}
