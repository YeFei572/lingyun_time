import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref);
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this.ref) : super(ThemeMode.light) {
    _load();
  }

  final Ref ref;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final store = await ref.read(themeConfigStoreProvider.future);
    await store.writeMap({'mode': _modeToJson(mode)});
  }

  Future<void> _load() async {
    final store = await ref.read(themeConfigStoreProvider.future);
    final map = await store.readMap();
    state = _modeFromJson(map['mode'] as String?);
  }

  ThemeMode _modeFromJson(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  String _modeToJson(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
  }
}
