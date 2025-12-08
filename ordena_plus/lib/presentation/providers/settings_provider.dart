import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State class for Settings
class SettingsState {
  final int gridColumns;

  SettingsState({this.gridColumns = 3});

  SettingsState copyWith({int? gridColumns}) {
    return SettingsState(gridColumns: gridColumns ?? this.gridColumns);
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

    state = SettingsState(gridColumns: gridColumns);
  }

  Future<void> setGridColumns(int columns) async {
    if (columns < 2 || columns > 5) return;
    state = state.copyWith(gridColumns: columns);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gridColumns', columns);
  }
}

// Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
