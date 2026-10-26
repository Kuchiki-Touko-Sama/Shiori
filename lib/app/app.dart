import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/shared/theme/app_theme.dart';
import 'package:shiori/shared/theme/theme_controller.dart';

/// 应用根组件：装配主题（种子色 / 动态取色 / OLED）与路由。
class ShioriApp extends ConsumerWidget {
  const ShioriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) =>
          _buildApp(ref, settings, lightDynamic, darkDynamic),
    );
  }

  Widget _buildApp(
    WidgetRef ref,
    AppThemeSettings settings,
    ColorScheme? lightDynamic,
    ColorScheme? darkDynamic,
  ) {
    final useDynamic = settings.useDynamicColor &&
        lightDynamic != null &&
        darkDynamic != null;
    return MaterialApp.router(
      title: 'Shiori 栞',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        brightness: Brightness.light,
        seedColor: settings.seedColor,
        dynamicColorScheme: useDynamic ? lightDynamic : null,
      ),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        seedColor: settings.seedColor,
        oledDark: settings.oledDark,
        dynamicColorScheme: useDynamic ? darkDynamic : null,
      ),
      themeMode: toMaterialThemeMode(settings.mode),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
