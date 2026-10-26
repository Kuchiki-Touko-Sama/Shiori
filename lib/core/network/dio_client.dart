import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/network/cookie_jar_provider.dart';
import 'package:shiori/core/network/webvpn_interceptor.dart';
import 'package:shiori/core/session/session_manager.dart';
import 'package:shiori/core/transport/webvpn_url.dart';

/// 全局 Dio 客户端 Provider。
///
/// 具备能力：
/// 1. 自动挂载持久化 Cookie 管理器（[CookieManager]）；
/// 2. 自动挂载 WebVPN 改写与会话过期检测拦截器（[WebVpnInterceptor]）；
/// 3. 统一移动端浏览器 User-Agent，保障教务系统兼容。
final dioClientProvider = Provider<Dio>((ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  final session = ref.watch(sessionControllerProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: <String, dynamic>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 Shiori/1.0',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ),
  );

  dio.interceptors.addAll([
    // 1. WebVpnInterceptor 必须先于 CookieManager 执行：
    // 校外模式下先将目标 URL（如 http://zhjw.hbu.cn/...）改写为网关代理 URL（https://v.hbu.cn/http/...）；
    // 使得后置的 CookieManager 能够精准以目标域名 v.hbu.cn 提取并注入网瑞达网关鉴权 Cookie。
    WebVpnInterceptor(
      rewriter: WebVpnUrlRewriter.hbu(),
      isWebVpnMode: () => session.networkMode == NetworkMode.webVpn,
      onSessionExpired: () {
        ref.read(sessionControllerProvider.notifier).markExpired();
      },
    ),
    // 2. CookieManager 根据最终请求的目标 URI 加载并回写 Cookie
    CookieManager(cookieJar),
  ]);

  return dio;
});
