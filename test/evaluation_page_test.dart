import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/gateway/edu_gateway.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/course.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/models/exam.dart';
import 'package:shiori/data/models/grade.dart';
import 'package:shiori/features/evaluation/evaluation_page.dart';

class TestEvaluationGateway implements EduSystemGateway {
  TestEvaluationGateway({List<EvaluationItem>? initial})
      : items = initial ??
            [
              const EvaluationItem(
                id: 'wj01_1001_c01',
                title: '教学问卷',
                courseName: '高等数学(上)',
                teacher: '李教授',
                wjbm: 'wj01',
                bpr: '1001',
                pgnr: 'c01',
              ),
              const EvaluationItem(
                id: 'wj01_1002_c02',
                title: '教学问卷',
                courseName: '大学英语(三)',
                teacher: '王老师',
                wjbm: 'wj01',
                bpr: '1002',
                pgnr: 'c02',
                status: EvaluationStatus.completed,
              ),
            ];

  final List<EvaluationItem> items;

  @override
  Future<List<EvaluationItem>> getEvaluations() async => items;

  @override
  Future<bool> submitEvaluation(
    EvaluationItem item, {
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
  }) async {
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      items[idx] = item.copyWith(status: EvaluationStatus.completed);
    }
    return true;
  }

  @override
  Future<List<Course>> getTimetable({String? semester}) async => const [];
  @override
  Future<List<ExamItem>> getExams({String? semester}) async => const [];
  @override
  Future<List<GradeItem>> getGrades({String? semester}) async => const [];
  @override
  Future<List<String>> getAvailableSemesters() async => const [];
}

void main() {
  testWidgets('EvaluationPage 展示概况与待评教列表，并支持一键好评', (tester) async {
    final gateway = TestEvaluationGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hbuUrpGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(
          home: EvaluationPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 验证顶部卡片与列表内容
    expect(find.text('评教任务概况'), findsOneWidget);
    expect(find.text('1 门待评'), findsOneWidget);
    expect(find.text('高等数学(上)'), findsOneWidget);
    expect(find.text('李教授'), findsOneWidget);

    // 验证一键好评按钮
    final batchBtn = find.text('一键好评全部未评课程');
    expect(batchBtn, findsOneWidget);

    // 点击一键评教
    await tester.tap(batchBtn);
    await tester.pumpAndSettle();

    // 对话框弹出
    expect(find.text('一键全选评教'), findsOneWidget);
    expect(find.text('开始一键评教'), findsOneWidget);

    // 点击确认提交
    await tester.tap(find.text('开始一键评教'));
    await tester.pumpAndSettle();

    // 验证状态更新为全部已评
    expect(find.text('全部已评'), findsOneWidget);
    expect(find.text('所有课程均已完成评教！'), findsOneWidget);
  });
}
