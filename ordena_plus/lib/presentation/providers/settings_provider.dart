import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State class for Settings
class SettingsState {
  final int gridColumns;
  final bool isAlbumsGrid;

  SettingsState({this.gridColumns = 3, this.isAlbumsGrid = true});

  SettingsState copyWith({int? gridColumns, bool? isAlbumsGrid}) {
    return SettingsState(
      gridColumns: gridColumns ?? this.gridColumns,
      isAlbumsGrid: isAlbumsGrid ?? this.isAlbumsGrid,
    );
  }
}

// Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Grid
    final gridColumns = prefs.getInt('gridColumns') ?? 3;
    final isAlbumsGrid = prefs.getBool('isAlbumsGrid') ?? true;

    state = SettingsState(gridColumns: gridColumns, isAlbumsGrid: isAlbumsGrid);
  }

  Future<void> setGridColumns(int columns) async {
    if (columns < 2 || columns > 5) return;
    state = state.copyWith(gridColumns: columns);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gridColumns', columns);
  }

  Future<void> setAlbumsGrid(bool isGrid) async {
    state = state.copyWith(isAlbumsGrid: isGrid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAlbumsGrid', isGrid);
  }
}

// Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
