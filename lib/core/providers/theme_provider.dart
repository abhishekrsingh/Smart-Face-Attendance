import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/app_logger.dart';

// ← NEW FILE
// FLOW:
//   1. App starts → build() reads Hive 'settings' box
//   2. Returns saved ThemeMode (defaults to system)
//   3. main.dart watches this provider
//   4. User taps toggle in Profile → toggle() called
//   5. state updates → Hive saves → MaterialApp re-renders
//   6. All widgets get new colorScheme automatically

const _hiveBox = 'settings';
const _themeKey = 'themeMode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSaved();
    // WHY return system first: build() is synchronous —
    //   _loadSaved updates state after Hive read (µs later)
    return ThemeMode.system;
  }

  Future<void> _loadSaved() async {
    try {
      final box = await Hive.openBox(_hiveBox);
      final saved = box.get(_themeKey, defaultValue: 'system') as String;
      state = _fromString(saved);
      AppLogger.debug('Theme loaded: $saved');
    } catch (e) {
      AppLogger.error('Theme load failed: $e');
      state = ThemeMode.system;
    }
  }

  // PURPOSE: Called from Profile page toggle
  Future<void> setTheme(ThemeMode mode) async {
    state = mode; // immediate UI update
    try {
      final box = await Hive.openBox(_hiveBox);
      await box.put(_themeKey, _toString(mode));
      AppLogger.info('Theme saved: ${_toString(mode)}');
    } catch (e) {
      AppLogger.error('Theme save failed: $e');
    }
  }

  // PURPOSE: Quick light ↔ dark toggle from Profile switch
  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(next);
  }

  ThemeMode _fromString(String s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _toString(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
    // ignore: unreachable_switch_case
    _ => 'system',
  };
}
