import 'package:equatable/equatable.dart';

enum FolderType { system, custom }

class Folder extends Equatable {
  final String id;
  final String name;
  final FolderType type;
  final String? iconPath; // For custom icons if needed, or use predefined icons
  final int order; // For sorting in the wheel

  const Folder({
    required this.id,
    required this.name,
    required this.type,
    this.iconPath,
    this.order = 0,
  });

  Folder copyWith({
    String? id,
    String? name,
    FolderType? type,
    String? iconPath,
    int? order,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconPath: iconPath ?? this.iconPath,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'iconPath': iconPath,
      'order': order,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      type: FolderType.values[map['type'] as int],
      iconPath: map['iconPath'] as String?,
      order: map['order'] as int? ?? 0,
    );
  }

  // System folder IDs
  static const String unorganizedId = 'unorganized';
  static const String trashId = 'trash';
  static const String photosId = 'photos';
  static const String videosId = 'videos';

  @override
  List<Object?> get props => [id, name, type, iconPath, order];
}
