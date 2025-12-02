import 'package:equatable/equatable.dart';

enum MediaType { photo, video }

class MediaItem extends Equatable {
  final String id;
  final String path;
  final MediaType type;
  final DateTime? dateCreated;
  final String? folderId;

  const MediaItem({
    required this.id,
    required this.path,
    required this.type,
    this.dateCreated,
    this.folderId,
  });

  MediaItem copyWith({
    String? id,
    String? path,
    MediaType? type,
    DateTime? dateCreated,
    String? folderId,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      dateCreated: dateCreated ?? this.dateCreated,
      folderId: folderId ?? this.folderId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'type': type.index,
      'dateCreated': dateCreated?.millisecondsSinceEpoch,
      'folderId': folderId,
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
    );
  }

  @override
  List<Object?> get props => [id, path, type, dateCreated, folderId];
}
