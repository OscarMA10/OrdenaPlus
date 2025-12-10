import 'package:flutter/material.dart';

class AlbumFormDialog extends StatefulWidget {
  final String? initialName;
  final String? initialIconKey;
  final int? initialColor;
  final String? initialStorageRoot; // For editing: the current storage root
  final List<String>
  storageVolumes; // Available volumes ['/storage/emulated/0', '/storage/SD-CARD-ID']
  final String title;
  final String confirmText;
  // Updated callback to include storageRoot
  final Function(String name, String iconKey, int color, String storageRoot)
  onConfirm;

  const AlbumFormDialog({
    super.key,
    this.initialName,
    this.initialIconKey,
    this.initialColor,
    this.initialStorageRoot,
    this.storageVolumes = const [
      '/storage/emulated/0',
    ], // Default to internal only
    required this.title,
    required this.confirmText,
    required this.onConfirm,
  });

  @override
  State<AlbumFormDialog> createState() => _AlbumFormDialogState();
}

class _AlbumFormDialogState extends State<AlbumFormDialog> {
  late TextEditingController _nameController;
  late String _selectedIconKey;
  late int _selectedColor;
  late String _selectedStorageRoot;

  // Predefined icons
  final Map<String, IconData> _icons = {
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
  };

  // Predefined colors
  final List<Color> _colors = [
    Colors.teal,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
    Colors.lime,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.deepOrange,
    Colors.deepPurple,
    Colors.lightBlue,
    Colors.lightGreen,
    Colors.yellow,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIconKey = widget.initialIconKey ?? 'folder';
    _selectedColor = widget.initialColor ?? Colors.teal.toARGB32();
    _selectedStorageRoot =
        widget.initialStorageRoot ?? widget.storageVolumes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getStorageLabel(String path) {
    if (path.contains('emulated/0')) {
      return 'Almacenamiento Interno';
    } else {
      // Extract last segment of path for SD card name
      final segments = path.split('/');
      final lastSegment = segments.isNotEmpty ? segments.last : 'SD';
      return 'Tarjeta SD ($lastSegment)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showStorageSelector = widget.storageVolumes.length > 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(
          maxHeight: 700,
        ), // Increased for storage option
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del álbum',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                autofocus: true,
              ),

              // Storage Selector (only if multiple volumes)
              if (showStorageSelector) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Almacenamiento',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStorageRoot,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      _selectedStorageRoot.contains('emulated/0')
                          ? Icons.phone_android
                          : Icons.sd_card,
                    ),
                  ),
                  items: widget.storageVolumes.map((volume) {
                    return DropdownMenuItem<String>(
                      value: volume,
                      child: Text(_getStorageLabel(volume)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStorageRoot = value);
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icono',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final key = _icons.keys.elementAt(index);
                    final icon = _icons[key]!;
                    final isSelected = _selectedIconKey == key;
                    return InkWell(
                      onTap: () => setState(() => _selectedIconKey = key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor).withValues(alpha: 0.2)
                              : null,
                          border: isSelected
                              ? Border.all(
                                  color: Color(_selectedColor),
                                  width: 2,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? Color(_selectedColor)
                              : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    final isSelected = _selectedColor == color.toARGB32();
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedColor = color.toARGB32()),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isNotEmpty) {
                        widget.onConfirm(
                          name,
                          _selectedIconKey,
                          _selectedColor,
                          _selectedStorageRoot,
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(_selectedColor),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(widget.confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
