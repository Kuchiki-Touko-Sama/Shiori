import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/parsers/evaluation_parser.dart';
import 'package:shiori/features/grades/grades_controller.dart';

void main() {
  group('河北大学真实评教接口 JSON 数据解析回归测试', () {
    late String realEvaluationJson;
    const parser = EvaluationParser();

    setUpAll(() {
      final file = File('test/fixtures/real_evaluation.json');
      expect(file.existsSync(), isTrue, reason: '必须存在真实评教 fixture 文件');
      realEvaluationJson = file.readAsStringSync();
    });

    test('完整解析 17 门真实已评课程与问卷参数', () {
      final items = parser.parseList(realEvaluationJson);

      expect(items.length, 17, reason: '应精确解析出 17 门评教记录');

      // 验证第 1 门：实验课
      final item0 = items[0];
      expect(item0.courseName, '现代控制理论实验');
      expect(item0.teacher, '姜萍');
      expect(item0.title, '实验课');
      expect(item0.wjbm, '0000000406');
      expect(item0.bpr, '12775');
      expect(item0.pgnr, '1323S04024');
      expect(item0.status, EvaluationStatus.completed);
      expect(item0.isCompleted, isTrue);

      // 验证第 6 门：理论课
      final item5 = items[5];
      expect(item5.courseName, '大学物理1');
      expect(item5.teacher, '董丽梅');
      expect(item5.title, '理论课');
      expect(item5.wjbm, '0000000407');
      expect(item5.bpr, '12691');
      expect(item5.pgnr, '1323D00001');
      expect(item5.status, EvaluationStatus.completed);

      // 验证所有 ID 唯一性
      final idSet = items.map((e) => e.id).toSet();
      expect(idSet.length, 17, reason: '17 门评教 ID 必须全局唯一无冲突');

      // 验证全量完成状态
      expect(items.every((e) => e.isCompleted), isTrue);
    });

    test('学期时间线正序比较测试（解决春季/秋季字典序导致的时序颠倒）', () {
      final semesters = [
        '2024-2025学年春季学期',
        '2023-2024学年秋季学期',
        '2025-2026学年春季学期',
        '2023-2024学年春季学期',
        '2024-2025学年秋季学期',
        '2025-2026学年秋季学期',
      ];

      // 正序（走趋势图）
      final ascending = List<String>.from(semesters)
        ..sort(GradesState.compareSemestersChronologically);

      expect(ascending, [
        '2023-2024学年秋季学期',
        '2023-2024学年春季学期',
        '2024-2025学年秋季学期',
        '2024-2025学年春季学期',
        '2025-2026学年秋季学期',
        '2025-2026学年春季学期',
      ]);

      // 降序（学期筛选器，最新在最前）
      final descending = List<String>.from(semesters)
        ..sort((a, b) => GradesState.compareSemestersChronologically(b, a));

      expect(descending.first, '2025-2026学年春季学期');
      expect(descending.last, '2023-2024学年秋季学期');
    });
  });
}
