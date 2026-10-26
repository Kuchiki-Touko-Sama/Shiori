import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/storage/shared_preferences_provider.dart';
import 'package:shiori/shared/theme/app_theme.dart';

/// 主题模式。
enum AppThemeMode { system, light, dark }

ThemeMode toMaterialThemeMode(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

/// 主题设置快照。
class AppThemeSettings {
  const AppThemeSettings({
    this.mode = AppThemeMode.system,
    this.seedColor = kDefaultSeedColor,
    this.useDynamicColor = false,
    this.oledDark = false,
  });

  final AppThemeMode mode;
  final Color seedColor;
  final bool useDynamicColor;
  final bool oledDark;

  AppThemeSettings copyWith({
    AppThemeMode? mode,
    Color? seedColor,
    bool? useDynamicColor,
    bool? oledDark,
  }) =>
      AppThemeSettings(
        mode: mode ?? this.mode,
        seedColor: seedColor ?? this.seedColor,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
        oledDark: oledDark ?? this.oledDark,
      );
}

/// 主题状态管理：全部改动即时生效并持久化到 SharedPreferences。
class ThemeController extends Notifier<AppThemeSettings> {
  static const _modeKey = 'theme.mode';
  static const _seedKey = 'theme.seedColor';
  static const _dynamicKey = 'theme.useDynamicColor';
  static const _oledKey = 'theme.oledDark';

  @override
  AppThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppThemeSettings(
      mode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == prefs.getString(_modeKey),
        orElse: () => AppThemeMode.system,
      ),
      seedColor: _readColor(prefs.getString(_seedKey)),
      useDynamicColor: prefs.getBool(_dynamicKey) ?? false,
      oledDark: prefs.getBool(_oledKey) ?? false,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_modeKey, mode.name);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    await ref.read(sharedPreferencesProvider).setString(
          _seedKey,
          _toHex(color),
        );
  }

  Future<void> setUseDynamicColor({required bool value}) async {
    state = state.copyWith(useDynamicColor: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_dynamicKey, value);
  }

  Future<void> setOledDark({required bool value}) async {
    state = state.copyWith(oledDark: value);
    await ref.read(sharedPreferencesProvider).setBool(_oledKey, value);
  }

  Color _readColor(String? hex) {
    if (hex == null || hex.length != 6) return kDefaultSeedColor;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return kDefaultSeedColor;
    return Color(0xFF000000 | value);
  }

  String _toHex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeSettings>(
  ThemeController.new,
);
