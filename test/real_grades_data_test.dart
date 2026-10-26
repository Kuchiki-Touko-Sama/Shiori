import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/calculator/gpa_calculator.dart';
import 'package:shiori/data/parsers/grade_parser.dart';

void main() {
  group('Real Grades Data Parsing Test', () {
    test('对齐河北大学真实返回的完整历年成绩 JSON 数据', () {
      final file = File('test/fixtures/real_grades.json');
      expect(file.existsSync(), isTrue, reason: '必须存在 real_grades.json 文件');
      final jsonString = file.readAsStringSync();

      const parser = GradeParser();
      final grades = parser.parse(jsonString);

      // 验证课程成绩总数
      expect(grades.length, 74);

      // 验证所有 ID 唯一性
      final ids = grades.map((g) => g.id).toSet();
      expect(ids.length, grades.length);

      // 验证第一学期代表课程：工程制图与CAD
      final cad = grades.firstWhere((g) => g.courseName == '工程制图与CAD');
      expect(cad.score, 79.0);
      expect(cad.credit, 2.0);
      expect(cad.gradePoint, 3.4);
      expect(cad.courseType, '必修');
      expect(cad.examType, '考试');
      expect(cad.semester, '2023-2024学年秋季学期');

      // 验证高绩点课程：C程序课程设计 (97分, 绩点 5.0)
      final cDesign = grades.firstWhere((g) => g.courseName == 'C程序课程设计');
      expect(cDesign.score, 97.0);
      expect(cDesign.gradePoint, 5.0);
      expect(cDesign.credit, 1.0);
      expect(cDesign.semester, '2023-2024学年秋季学期');

      // 验证近年代表课程：自动控制原理A (63分, 绩点 1.6, 4.0学分)
      final autoControl = grades.firstWhere((g) => g.courseName == '自动控制原理A');
      expect(autoControl.score, 63.0);
      expect(autoControl.gradePoint, 1.6);
      expect(autoControl.credit, 4.0);
      expect(autoControl.semester, '2025-2026学年秋季学期');

      // 验证学期列表提取
      final semesters = grades.map((g) => g.semester).toSet();
      expect(semesters.contains('2023-2024学年秋季学期'), isTrue);
      expect(semesters.contains('2023-2024学年春季学期'), isTrue);
      expect(semesters.contains('2024-2025学年秋季学期'), isTrue);
      expect(semesters.contains('2024-2025学年春季学期'), isTrue);
      expect(semesters.contains('2025-2026学年秋季学期'), isTrue);

      // 验证 GPA 计算准确运行
      final overallGpa = GpaCalculator.calculate(
        grades: grades,
      );
      expect(overallGpa.gpa, greaterThan(2.0));
      expect(overallGpa.gpa, lessThan(4.5));
      expect(overallGpa.totalCredits, greaterThan(50.0));
    });
  });
}
