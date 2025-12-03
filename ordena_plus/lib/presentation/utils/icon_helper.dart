import 'package:flutter/material.dart';

class IconHelper {
  static const Map<String, IconData> _icons = {
    'folder': Icons.folder,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'work': Icons.work,
    'flight': Icons.flight,
    'home': Icons.home,
    'school': Icons.school,
    'pets': Icons.pets,
    'sports_soccer': Icons.sports_soccer,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'camera_alt': Icons.camera_alt,
    'shopping_cart': Icons.shopping_cart,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'beach_access': Icons.beach_access,
    'fitness_center': Icons.fitness_center,
    'gamepad': Icons.gamepad,
    'book': Icons.book,
    'lightbulb': Icons.lightbulb,
    'inbox': Icons.inbox,
    'delete': Icons.delete,
    'photo_library': Icons.photo_library,
    'video_library': Icons.video_library,
  };

  static IconData getIcon(String? key) {
    return _icons[key] ?? Icons.folder;
  }
}
