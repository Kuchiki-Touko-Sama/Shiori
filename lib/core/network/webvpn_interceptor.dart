import 'package:dio/dio.dart';
import 'package:shiori/core/transport/webvpn_url.dart';

/// 会话失效回调。
typedef SessionExpiredCallback = void Function();

/// 网瑞达（WebVPN）请求与会话拦截器。
///
/// 1. 在校外 WebVPN 模式下，自动把教务内网地址转换为 WebVPN 加密访问地址；
/// 2. 监听响应，若被重定向至登录页或返回未登录页面，触发 [onSessionExpired]。
class WebVpnInterceptor extends Interceptor {
  WebVpnInterceptor({
    required this.rewriter,
    required this.isWebVpnMode,
    this.onSessionExpired,
    this.gracePeriod = const Duration(seconds: 5),
  });

  /// WebVPN URL 改写工具
  final WebVpnUrlRewriter rewriter;

  /// 是否处于 WebVPN 访问模式（校外）
  final bool Function() isWebVpnMode;

  /// 会话过期通知回调
  final SessionExpiredCallback? onSessionExpired;

  /// 刚完成登录认证后的免扰过渡期（防止并发拉取请求瞬断误判）
  final Duration gracePeriod;

  /// 最近一次认证成功的时刻
  static DateTime? lastAuthenticatedAt;

  /// 标记当前完成认证，启动过渡保护期
  static void markAuthenticatedNow() {
    lastAuthenticatedAt = DateTime.now();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isWebVpnMode()) {
      final uri = options.uri;
      if (uri.hasScheme &&
          uri.host.isNotEmpty &&
          uri.host != rewriter.webvpnHost) {
        final webvpnUri = rewriter.toWebVpn(uri);
        options
          ..path = webvpnUri.toString()
          ..queryParameters = <String, dynamic>{};
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (_isSessionExpired(data, response.realUri)) {
      final lastAuth = lastAuthenticatedAt;
      final inGracePeriod = lastAuth != null &&
          DateTime.now().difference(lastAuth) < gracePeriod;
      if (!inGracePeriod) {
        onSessionExpired?.call();
      }
    }
    handler.next(response);
  }

  bool _isSessionExpired(dynamic data, Uri realUri) {
    final host = realUri.host.toLowerCase();
    final path = realUri.path.toLowerCase();

    // 1. 如果重定向回 WebVPN 网关自身的登录页或 CAS 认证页（非代理路径）
    if (host == rewriter.webvpnHost || host.contains('sso.hbu.cn')) {
      if (path == '/login' ||
          path.startsWith('/cas/') ||
          path.contains('/auth/')) {
        return true;
      }
    }

    // 2. 检查响应内容中的未登录特征提示
    if (data is String) {
      if (data.contains('统一身份认证') && data.contains('password')) {
        return true;
      }
      if (data.contains('您尚未登录') ||
          data.contains('用户未登录') ||
          data.contains('请重新登录')) {
        return true;
      }
    }
    return false;
  }
}
