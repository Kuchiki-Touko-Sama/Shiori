import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局 Cookie 管理器 Provider。
///
/// 默认提供纯内存 [CookieJar]（便于单元测试）；
/// 实际应用在 `main.dart` 中将其覆盖为 [PersistCookieJar]。
final cookieJarProvider = Provider<CookieJar>((ref) {
  return CookieJar();
});
