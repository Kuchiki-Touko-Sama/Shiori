import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/network/webvpn_interceptor.dart';
import 'package:shiori/core/transport/webvpn_url.dart';

void main() {
  group('Dio 拦截器顺序与 Cookie 注入验证', () {
    late CookieJar cookieJar;
    late WebVpnUrlRewriter rewriter;

    setUp(() async {
      cookieJar = CookieJar();
      rewriter = WebVpnUrlRewriter.hbu();
      WebVpnInterceptor.lastAuthenticatedAt = null;
      WebVpnUrlRewriter.clearValidatedSegments();

      // 在 CookieJar 中保存 WebVPN 网关凭据
      await cookieJar.saveFromResponse(
        Uri.parse('https://v.hbu.cn/'),
        [
          io.Cookie('wrdvpnisthebest!', 'token_123456')
            ..domain = 'v.hbu.cn'
            ..path = '/',
          io.Cookie('webvpn_user', '20230001')
            ..domain = 'v.hbu.cn'
            ..path = '/',
        ],
      );
    });

    test('WebVpnInterceptor 先于 CookieManager 执行时，发往网关的请求成功注入 v.hbu.cn 的 Cookie',
        () async {
      final dio = Dio();
      RequestOptions? capturedOptions;

      // 正确顺序：先 WebVpn 改写，后 CookieManager 注入，最后捕获 options 并 resolve 模拟响应
      dio.interceptors.addAll([
        WebVpnInterceptor(
          rewriter: rewriter,
          isWebVpnMode: () => true,
        ),
        CookieManager(cookieJar),
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            handler.resolve(
              Response<String>(
                requestOptions: options,
                data: 'ok',
                statusCode: 200,
              ),
            );
          },
        ),
      ]);

      await dio.get<String>(
        'http://zhjw.hbu.cn/student/courseSelect/calendarSchedule/index',
      );

      expect(capturedOptions, isNotNull);
      // 验证 1：URL 已被成功改写为 v.hbu.cn 代理地址
      expect(capturedOptions!.path.startsWith('https://v.hbu.cn/http/'), isTrue);

      // 验证 2：目标 URI 的 host 是 v.hbu.cn
      expect(capturedOptions!.uri.host, 'v.hbu.cn');

      // 验证 3：CookieManager 成功将 v.hbu.cn 域下的 Cookie 注入到 headers
      final cookieHeader = capturedOptions!.headers['cookie'] as String?;
      expect(cookieHeader, isNotNull);
      expect(cookieHeader, contains('wrdvpnisthebest!=token_123456'));
      expect(cookieHeader, contains('webvpn_user=20230001'));
    });
  });
}
