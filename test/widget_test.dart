import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/core/storage/shared_preferences_provider.dart';
import 'package:shiori/data/gateway/edu_gateway.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/course.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/models/exam.dart';
import 'package:shiori/data/models/grade.dart';

class LocalTestEduGateway implements EduSystemGateway {
  @override
  Future<List<Course>> getTimetable({String? semester}) async =>
      HbuUrpGateway.sampleCourses;

  @override
  Future<List<ExamItem>> getExams({String? semester}) async =>
      HbuUrpGateway.sampleExams;

  @override
  Future<List<GradeItem>> getGrades({String? semester}) async =>
      HbuUrpGateway.sampleGrades;

  @override
  Future<List<String>> getAvailableSemesters() async =>
      const <String>['2026-2027学年秋季学期'];

  @override
  Future<List<EvaluationItem>> getEvaluations() async =>
      HbuUrpGateway.sampleEvaluations;

  @override
  Future<bool> submitEvaluation(
    EvaluationItem item, {
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
  }) async =>
      true;
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hbuUrpGatewayProvider.overrideWithValue(LocalTestEduGateway()),
        ],
        child: const ShioriApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App 启动并显示底部导航与课表页', (tester) async {
    await pumpApp(tester);

    expect(find.text('课表'), findsWidgets);
    expect(find.text('成绩'), findsWidgets);
    expect(find.text('考试'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('第 1 周'), findsOneWidget);
  });

  testWidgets('切换到「成绩」页并显示 GPA 与成绩列表', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('成绩').first);
    await tester.pumpAndSettle();

    expect(find.text('成绩与 GPA'), findsOneWidget);
    expect(find.text('平均绩点 (GPA)'), findsOneWidget);
    expect(find.text('全部历年'), findsOneWidget);
  });

  testWidgets('切换到「考试」页并显示考试安排', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('考试').first);
    await tester.pumpAndSettle();

    expect(find.text('考试安排'), findsOneWidget);
  });

  testWidgets('切换到「我的」页并显示主题设置', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('Material You 动态取色'), findsOneWidget);
    expect(find.text('OLED 纯黑背景'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
  });

  testWidgets('OLED 开关切换后主题背景变为纯黑', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('OLED 纯黑背景'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OLED 纯黑背景'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).scaffoldBackgroundColor, Colors.black);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme.oledDark'), isTrue);
    expect(prefs.getString('theme.mode'), 'dark');
  });
}
