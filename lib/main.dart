import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/core/network/cookie_jar_provider.dart';
import 'package:shiori/core/storage/shared_preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final appDir = await getApplicationSupportDirectory();
  final cookieDir = Directory('${appDir.path}/cookies');
  if (!cookieDir.existsSync()) {
    await cookieDir.create(recursive: true);
  }
  final cookieJar = PersistCookieJar(
    storage: FileStorage(cookieDir.path),
    ignoreExpires: true,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cookieJarProvider.overrideWithValue(cookieJar),
      ],
      child: const ShioriApp(),
    ),
  );
}
