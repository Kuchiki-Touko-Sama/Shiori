import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 用户保存的学号与密码凭据。
class UserCredentials {
  const UserCredentials({
    this.username,
    this.password,
  });

  /// 学号
  final String? username;

  /// 密码
  final String? password;

  /// 是否包含完整的学号与密码
  bool get hasCredentials =>
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;
}

/// 基于系统安全存储（Android Keystore）的安全凭据存储。
class SecretStore {
  SecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _keyUsername = 'auth_username';
  static const String _keyPassword = 'auth_password';
  static const String _keyRemember = 'auth_remember_password';

  /// 保存用户凭据与「记住密码」标记。
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyRemember, value: 'true');
  }

  /// 读取已保存的凭据。
  Future<UserCredentials> readCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return UserCredentials(username: username, password: password);
  }

  /// 仅读取已保存的学号。
  Future<String?> readUsername() => _storage.read(key: _keyUsername);

  /// 是否开启了「记住密码」。
  Future<bool> isRememberPassword() async {
    final val = await _storage.read(key: _keyRemember);
    return val == 'true';
  }

  /// 清除凭据与记住密码标记。
  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyRemember);
  }
}

/// 纯内存实现的凭据存储（主要用于单元测试与快速预览）。
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _data = <String, String>{};

  @override
  FlutterSecureStorage get _storage => throw UnimplementedError();

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    _data[SecretStore._keyUsername] = username;
    _data[SecretStore._keyPassword] = password;
    _data[SecretStore._keyRemember] = 'true';
  }

  @override
  Future<UserCredentials> readCredentials() async {
    return UserCredentials(
      username: _data[SecretStore._keyUsername],
      password: _data[SecretStore._keyPassword],
    );
  }

  @override
  Future<String?> readUsername() async => _data[SecretStore._keyUsername];

  @override
  Future<bool> isRememberPassword() async =>
      _data[SecretStore._keyRemember] == 'true';

  @override
  Future<void> clearCredentials() async {
    _data.clear();
  }
}

/// 安全存储 Provider。
final secretStoreProvider = Provider<SecretStore>((ref) {
  return SecretStore();
});
