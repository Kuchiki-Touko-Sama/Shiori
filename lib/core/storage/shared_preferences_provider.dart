import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局 [SharedPreferences]。
///
/// 在 `main()` 中完成初始化后通过 `overrideWithValue` 注入，
/// 保证任何 Provider 在读取时无需等待异步初始化。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider 未注入：请在 main() 中 override',
  );
});
