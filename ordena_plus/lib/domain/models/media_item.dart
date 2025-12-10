import 'package:equatable/equatable.dart';

enum MediaType { photo, video }

class MediaItem extends Equatable {
  final String id;
  final String path;
  final MediaType type;
  final DateTime? dateCreated;
  final String? folderId;
  final String? originalPath;

  const MediaItem({
    required this.id,
    required this.path,
    required this.type,
    this.dateCreated,
    this.folderId,
    this.originalPath,
  });

  MediaItem copyWith({
    String? id,
    String? path,
    MediaType? type,
    DateTime? dateCreated,
    String? folderId,
    String? originalPath,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      dateCreated: dateCreated ?? this.dateCreated,
      folderId: folderId ?? this.folderId,
      originalPath: originalPath ?? this.originalPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'type': type.index,
      'dateCreated': dateCreated?.millisecondsSinceEpoch,
      'folderId': folderId,
      'originalPath': originalPath,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as String,
      path: map['path'] as String,
      type: MediaType.values[map['type'] as int],
      dateCreated: map['dateCreated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateCreated'] as int)
          : null,
      folderId: map['folderId'] as String?,
      originalPath: map['originalPath'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    path,
    type,
    dateCreated,
    folderId,
    originalPath,
  ];
}
