import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/network/cookie_jar_provider.dart';
import 'package:shiori/core/storage/secret_store.dart';
import 'package:shiori/core/storage/shared_preferences_provider.dart';

/// 认证状态。
enum AuthStatus {
  /// 初始状态（尚未检查本地 Cookie 或凭据）
  initial,

  /// 未登录
  unauthenticated,

  /// 正在认证 / 正在同步 Cookie
  authenticating,

  /// 已登录
  authenticated,

  /// 会话已过期（需重新登录）
  expired,
}

/// 访问网络模式。
enum NetworkMode {
  /// 校外：通过 WebVPN（v.hbu.cn）访问
  webVpn,

  /// 校内：直连校园网教务系统
  direct,
}

/// 会话状态。
class SessionState {
  const SessionState({
    this.status = AuthStatus.initial,
    this.username,
    this.networkMode = NetworkMode.webVpn,
    this.lastLoginTime,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? username;
  final NetworkMode networkMode;
  final DateTime? lastLoginTime;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isWebVpn => networkMode == NetworkMode.webVpn;

  SessionState copyWith({
    AuthStatus? status,
    String? username,
    bool clearUsername = false,
    NetworkMode? networkMode,
    DateTime? lastLoginTime,
    bool clearLoginTime = false,
    String? errorMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      username: clearUsername ? null : (username ?? this.username),
      networkMode: networkMode ?? this.networkMode,
      lastLoginTime:
          clearLoginTime ? null : (lastLoginTime ?? this.lastLoginTime),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 会话控制器。
class SessionController extends Notifier<SessionState> {
  static const String _kKeyUsername = 'session.username';
  static const String _kKeyNetworkMode = 'session.network_mode';

  @override
  SessionState build() {
    // 异步检查本地已存凭据与 Cookie
    unawaited(checkInitialSession());
    return const SessionState();
  }

  /// 检查本地会话与凭据状态。
  Future<void> checkInitialSession() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedUsername = prefs.getString(_kKeyUsername);
    final modeStr = prefs.getString(_kKeyNetworkMode);
    final networkMode = modeStr == NetworkMode.direct.name
        ? NetworkMode.direct
        : NetworkMode.webVpn;

    final cookieJar = ref.read(cookieJarProvider);
    final vpnUri = Uri.parse('https://v.hbu.cn/');
    final cookies = await cookieJar.loadForRequest(vpnUri);

    final hasValidCookie = cookies.any((c) {
      final name = c.name.toLowerCase();
      return name.contains('wrdvpn') ||
          name.contains('webvpn') ||
          name.contains('castgc') ||
          name.contains('session');
    });

    if (hasValidCookie) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        username: savedUsername,
        networkMode: networkMode,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        username: savedUsername,
        networkMode: networkMode,
      );
    }
  }

  /// 切换网络访问模式（WebVPN / 直连）。
  Future<void> setNetworkMode(NetworkMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kKeyNetworkMode, mode.name);
    state = state.copyWith(networkMode: mode);
  }

  /// 标记为正在登录中。
  void markAuthenticating() {
    state = state.copyWith(status: AuthStatus.authenticating);
  }

  /// 登录成功更新状态。
  Future<void> markAuthenticated({
    required String username,
    DateTime? loginTime,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (username.isNotEmpty) {
      await prefs.setString(_kKeyUsername, username);
    }
    state = state.copyWith(
      status: AuthStatus.authenticated,
      username: username.isNotEmpty ? username : state.username,
      lastLoginTime: loginTime ?? DateTime.now(),
    );
  }

  /// 标记会话已过期。
  void markExpired() {
    if (state.status == AuthStatus.authenticated) {
      state = state.copyWith(status: AuthStatus.expired);
    }
  }

  /// 退出登录：清空 Cookie、按需清除安全凭据。
  Future<void> logout() async {
    final cookieJar = ref.read(cookieJarProvider);
    await cookieJar.deleteAll();

    final secretStore = ref.read(secretStoreProvider);
    final remember = await secretStore.isRememberPassword();
    if (!remember) {
      await secretStore.clearCredentials();
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kKeyUsername);

    state = SessionState(
      status: AuthStatus.unauthenticated,
      networkMode: state.networkMode,
    );
  }
}

/// 会话控制器 Provider。
final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
