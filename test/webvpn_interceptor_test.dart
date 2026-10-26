import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/network/webvpn_interceptor.dart';
import 'package:shiori/core/transport/webvpn_url.dart';

void main() {
  group('WebVpnInterceptor URL 改写与会话监控测试', () {
    late WebVpnUrlRewriter rewriter;

    setUp(() {
      rewriter = WebVpnUrlRewriter.hbu();
      WebVpnInterceptor.lastAuthenticatedAt = null;
      WebVpnUrlRewriter.clearValidatedSegments();
    });

    test('WebVPN 模式下自动改写内网教务 URL', () {
      const isVpn = true;
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => isVpn,
      );

      final options = RequestOptions(
        path: 'http://jwxt.hbu.edu.cn/xkAction.do?actionType=6',
      );

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.path.startsWith('https://v.hbu.cn/http/'), isTrue);
      expect(options.queryParameters, isEmpty);
    });

    test('校园网直连模式下不改写 URL', () {
      const isVpn = false;
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => isVpn,
      );

      const rawUrl = 'http://jwxt.hbu.edu.cn/xkAction.do?actionType=6';
      final options = RequestOptions(path: rawUrl);

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.path, rawUrl);
    });

    test('已经是 v.hbu.cn 的请求不重复改写', () {
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => true,
      );

      const vpnUrl = 'https://v.hbu.cn/login';
      final options = RequestOptions(path: vpnUrl);

      final handler = RequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(options.path, vpnUrl);
    });

    test('重定向到 /login 触发 onSessionExpired 回调', () {
      var expiredTriggered = false;
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => true,
        onSessionExpired: () {
          expiredTriggered = true;
        },
      );

      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: 'https://v.hbu.cn/login'),
        data: '<html>登录页</html>',
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(expiredTriggered, isTrue);
    });

    test('响应内容包含未登录关键字触发 onSessionExpired', () {
      var expiredTriggered = false;
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => true,
        onSessionExpired: () {
          expiredTriggered = true;
        },
      );

      final response = Response<dynamic>(
        requestOptions:
            RequestOptions(path: 'https://v.hbu.cn/http/test/score'),
        data: '<div>错误：您尚未登录，请重新认证</div>',
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(expiredTriggered, isTrue);
    });

    test('在认证成功过渡保护期内不触发 onSessionExpired', () {
      var expiredTriggered = false;
      final interceptor = WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => true,
        onSessionExpired: () {
          expiredTriggered = true;
        },
      );

      // 模拟刚刚认证成功
      WebVpnInterceptor.markAuthenticatedNow();

      final response = Response<dynamic>(
        requestOptions: RequestOptions(path: 'https://v.hbu.cn/login'),
        data: '<html>登录页</html>',
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(expiredTriggered, isFalse);
    });

    test('动态注册权威 Host Segment 后优先使用权威密文', () {
      const customSeg = '77726476706e69737468656265737421abcdef1234567890';
      WebVpnUrlRewriter.registerValidatedSegment('zhjw.hbu.cn', customSeg);

      final options = RequestOptions(
        path: 'http://zhjw.hbu.cn/student/courseSelect',
      );

      WebVpnInterceptor(
        rewriter: rewriter,
        isWebVpnMode: () => true,
      ).onRequest(options, RequestInterceptorHandler());

      expect(
        options.path,
        'https://v.hbu.cn/http/$customSeg/student/courseSelect',
      );
    });
  });
}
