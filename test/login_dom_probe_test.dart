import 'package:flutter_test/flutter_test.dart';

void main() {
  group('登录 DOM 探针与新版 URP 特征提取测试', () {
    final welcomeRegex = RegExp(r'欢迎您[，,:：\s]*([^\s\n\r<,，!！]+)');

    test('从图 3 特征文本中准确提取学生姓名', () {
      const pageText = '''
        2026-2027 秋 第9周 星期一
        欢迎您，赵睿哲
        主修/辅修方案管理
        我的待办任务 1
      ''';

      final match = welcomeRegex.firstMatch(pageText);
      expect(match, isNotNull);
      expect(match?.group(1), '赵睿哲');
    });

    test('兼容不同格式的欢迎文本', () {
      const samples = {
        '欢迎您：张三': '张三',
        '欢迎您,李四': '李四',
        '欢迎您 王五': '王五',
        '欢迎您，赵睿哲同学': '赵睿哲同学',
      };

      for (final entry in samples.entries) {
        final match = welcomeRegex.firstMatch(entry.key);
        expect(match?.group(1), entry.value);
      }
    });

    test('准确识别 URP 新版教务系统与排除 CAS 登录页', () {
      // 图 3 特征
      const urpPage = '''
        <title>URP高校教务管理系统</title>
        <div>欢迎您，赵睿哲</div>
        <div>我的待办任务 1</div>
      ''';

      final isUrp = urpPage.contains('URP') ||
          urpPage.contains('URP高校教务管理系统') ||
          urpPage.contains('主修/辅修方案管理');
      expect(isUrp, isTrue);

      // 图 1 CAS 认证页特征
      const casPage = '''
        <title>河北大学 | 统一身份认证平台</title>
        <input name="username" value="20231806007">
        <div>5 + 3 =</div>
        <div>您正在使用VPN</div>
      ''';

      final isCasUrp = casPage.contains('URP高校教务管理系统') ||
          casPage.contains('主修/辅修方案管理') ||
          casPage.contains('我的待办任务');
      expect(isCasUrp, isFalse);
    });
  });
}
