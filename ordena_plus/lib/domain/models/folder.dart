import 'package:equatable/equatable.dart';

enum FolderType { system, custom }

class Folder extends Equatable {
  final String id;
  final String name;
  final String? iconPath; // Keeping for backward compatibility or custom images
  final String? iconKey; // New: Key for Material Icons (e.g., 'star', 'work')
  final int? color; // New: Color value (int)
  final FolderType type;
  final int order;

  const Folder({
    required this.id,
    required this.name,
    this.iconPath,
    this.iconKey,
    this.color,
    this.type = FolderType.custom,
    this.order = 0,
  });

  // System folder IDs
  static const String unorganizedId = 'unorganized';
  static const String trashId = 'trash';

  Folder copyWith({
    String? name,
    String? iconPath,
    String? iconKey,
    int? color,
    FolderType? type,
    int? order,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      iconKey: iconKey ?? this.iconKey,
      color: color ?? this.color,
      type: type ?? this.type,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconPath': iconPath,
      'iconKey': iconKey,
      'color': color,
      'type': type.index,
      'order_index':
          order, // Note: DB column is order_index to avoid keyword conflict
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      iconPath: map['iconPath'] as String?,
      iconKey: map['iconKey'] as String?,
      color: map['color'] as int?,
      type: FolderType.values[map['type'] as int],
      order: map['order_index'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, iconPath, iconKey, color, type, order];
}
