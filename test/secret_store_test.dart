import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/secret_store.dart';

void main() {
  group('InMemorySecretStore 凭据存储测试', () {
    late InMemorySecretStore store;

    setUp(() {
      store = InMemorySecretStore();
    });

    test('保存凭据后能够正确读取', () async {
      await store.saveCredentials(
        username: '20240001',
        password: 'mySecretPassword',
      );

      final creds = await store.readCredentials();
      expect(creds.hasCredentials, isTrue);
      expect(creds.username, '20240001');
      expect(creds.password, 'mySecretPassword');

      expect(await store.readUsername(), '20240001');
      expect(await store.isRememberPassword(), isTrue);
    });

    test('clearCredentials 清空已存凭据', () async {
      await store.saveCredentials(
        username: '20240001',
        password: 'mySecretPassword',
      );

      await store.clearCredentials();

      final creds = await store.readCredentials();
      expect(creds.hasCredentials, isFalse);
      expect(creds.username, isNull);
      expect(creds.password, isNull);
      expect(await store.isRememberPassword(), isFalse);
    });
  });
}
