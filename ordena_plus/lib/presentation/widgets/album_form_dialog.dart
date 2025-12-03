import 'package:flutter/material.dart';

class AlbumFormDialog extends StatefulWidget {
  final String? initialName;
  final String? initialIconKey;
  final int? initialColor;
  final String title;
  final String confirmText;
  final Function(String name, String iconKey, int color) onConfirm;

  const AlbumFormDialog({
    super.key,
    this.initialName,
    this.initialIconKey,
    this.initialColor,
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
    _selectedColor = widget.initialColor ?? Colors.teal.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                            ? Color(_selectedColor).withAlpha(50)
                            : null,
                        border: isSelected
                            ? Border.all(color: Color(_selectedColor), width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Color(_selectedColor) : Colors.grey,
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
                  final isSelected = _selectedColor == color.value;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color.value),
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
                                  color: Colors.black.withAlpha(50),
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
                      widget.onConfirm(name, _selectedIconKey, _selectedColor);
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
    );
  }
}
