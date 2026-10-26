import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/updater/update_checker.dart';

void main() {
  group('UpdateChecker 版本比对与检查测试', () {
    test('正确处理无网络或响应异常时的默认返回值', () async {
      final dio = Dio();
      // 指向不存在的路径快速触发异常
      final checker = UpdateChecker(
        dio: dio,
        repoOwner: 'invalid_owner_test',
        repoName: 'invalid_repo_test',
      );

      final result = await checker.check();
      expect(result.hasUpdate, isFalse);
      expect(result.currentVersion, '1.0.0');
      expect(result.latestVersion, '1.0.0');
    });
  });
}
