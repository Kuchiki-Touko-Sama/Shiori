import 'package:flutter/material.dart';

/// 默认种子色：Material 绿（与 Kazumi 默认一致）。
const Color kDefaultSeedColor = Color(0xFF4CAF50);

/// 预设主题色板（绿色系为主）。
const List<Color> kSeedColorPresets = <Color>[
  Color(0xFF4CAF50), // Kazumi 默认绿
  Color(0xFF2E7D32), // 松柏绿
  Color(0xFF66BB6A), // 叶绿
  Color(0xFF00897B), // 青碧
  Color(0xFF8BC34A), // 嫩芽绿
  Color(0xFF00C853), // 亮绿
];

/// 构建应用主题。
///
/// [dynamicColorScheme] 非空时（Material You 动态取色）优先使用系统配色，
/// 此时 [seedColor] 仅作为回退。OLED 纯黑模式把深色主题的背景统一替换为
/// 纯黑以省电。
ThemeData buildAppTheme({
  required Brightness brightness,
  Color seedColor = kDefaultSeedColor,
  bool oledDark = false,
  ColorScheme? dynamicColorScheme,
}) {
  var colorScheme = dynamicColorScheme ??
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      );
  final isDark = brightness == Brightness.dark;
  final useOled = oledDark && isDark;
  if (useOled) {
    colorScheme = colorScheme.copyWith(
      surface: Colors.black,
      onSurface: Colors.white,
    );
  }
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: useOled ? Colors.black : colorScheme.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      circularTrackColor: colorScheme.surfaceContainerHighest,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: useOled ? Colors.black : null,
      indicatorColor: colorScheme.secondaryContainer,
    ),
  );
}
