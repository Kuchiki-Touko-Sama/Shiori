import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiori/core/network/cookie_jar_provider.dart';
import 'package:shiori/core/session/session_manager.dart';
import 'package:shiori/core/storage/secret_store.dart';
import 'package:shiori/core/storage/shared_preferences_provider.dart';

void main() {
  group('SessionController 状态流转测试', () {
    late SharedPreferences prefs;
    late CookieJar cookieJar;
    late InMemorySecretStore secretStore;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      cookieJar = CookieJar();
      secretStore = InMemorySecretStore();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cookieJarProvider.overrideWithValue(cookieJar),
          secretStoreProvider.overrideWithValue(secretStore),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('初始无 Cookie 状态为 unauthenticated', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.checkInitialSession();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isAuthenticated, isFalse);
    });

    test('存在 WebVPN 会话 Cookie 时自动识别为 authenticated', () async {
      final vpnUri = Uri.parse('https://v.hbu.cn/');
      await cookieJar.saveFromResponse(vpnUri, [
        Cookie('wrdvpnismeaningful!', 'test_session_id'),
      ]);
      await prefs.setString('session.username', '20240101');

      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.checkInitialSession();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.username, '20240101');
    });

    test('真实网瑞达票据 Cookie (wengine_vpn_ticket) 启动冷启动被正确识别为 authenticated', () async {
      final vpnUri = Uri.parse('https://v.hbu.cn/');
      await cookieJar.saveFromResponse(vpnUri, [
        Cookie('wengine_vpn_ticketv_hbu_cn', 'mock_ticket_12345'),
      ]);
      await prefs.setString('session.username', '20231806007');

      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.checkInitialSession();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.username, '20231806007');
    });

    test('冷启动时若已持久化 is_authenticated 标记直接判定为已登录', () async {
      await prefs.setBool('session.is_authenticated', true);
      await prefs.setString('session.username', '20231806007');

      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.checkInitialSession();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
    });

    test('登录成功 markAuthenticated 更新状态与持久化学号', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.markAuthenticated(username: '20241234');

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.username, '20241234');
      expect(prefs.getString('session.username'), '20241234');
    });

    test('会话过期 markExpired 正常流转', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.markAuthenticated(username: '20241234');
      controller.markExpired();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.expired);
      expect(state.isAuthenticated, isFalse);
    });

    test('网络模式切换 setNetworkMode 持久化与状态更新', () async {
      final controller =
          container.read(sessionControllerProvider.notifier);

      expect(
        container.read(sessionControllerProvider).networkMode,
        NetworkMode.webVpn,
      );

      await controller.setNetworkMode(NetworkMode.direct);
      expect(
        container.read(sessionControllerProvider).networkMode,
        NetworkMode.direct,
      );
      expect(prefs.getString('session.network_mode'), 'direct');

      await controller.setNetworkMode(NetworkMode.webVpn);
      expect(
        container.read(sessionControllerProvider).networkMode,
        NetworkMode.webVpn,
      );
    });

    test('退出登录 logout 清空 Cookie 与用户状态', () async {
      final vpnUri = Uri.parse('https://v.hbu.cn/');
      await cookieJar.saveFromResponse(vpnUri, [
        Cookie('wrdvpnismeaningful!', 'test_session_id'),
      ]);
      final controller =
          container.read(sessionControllerProvider.notifier);
      await controller.markAuthenticated(username: '20241234');

      await controller.logout();

      final state = container.read(sessionControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.username, isNull);
      expect(prefs.getString('session.username'), isNull);

      final cookies = await cookieJar.loadForRequest(vpnUri);
      expect(cookies, isEmpty);
    });
  });
}
