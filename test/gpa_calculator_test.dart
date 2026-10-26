import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/calculator/gpa_calculator.dart';
import 'package:shiori/data/models/grade.dart';

void main() {
  group('GpaCalculator 算法与汇总测试', () {
    test('单门课程绩点换算（河大 4.0 制）', () {
      expect(GpaCalculator.calculatePoint(100, GpaAlgorithm.hbu4), 4.0);
      expect(GpaCalculator.calculatePoint(90, GpaAlgorithm.hbu4), 4.0);
      expect(GpaCalculator.calculatePoint(85, GpaAlgorithm.hbu4), 3.5);
      expect(GpaCalculator.calculatePoint(60, GpaAlgorithm.hbu4), 1.0);
      expect(GpaCalculator.calculatePoint(59, GpaAlgorithm.hbu4), 0.0);
    });

    test('单门课程绩点换算（标准 4.0 阶梯制）', () {
      expect(GpaCalculator.calculatePoint(95, GpaAlgorithm.standard4), 4.0);
      expect(GpaCalculator.calculatePoint(85, GpaAlgorithm.standard4), 3.0);
      expect(GpaCalculator.calculatePoint(75, GpaAlgorithm.standard4), 2.0);
      expect(GpaCalculator.calculatePoint(65, GpaAlgorithm.standard4), 1.0);
      expect(GpaCalculator.calculatePoint(55, GpaAlgorithm.standard4), 0.0);
    });

    test('等第成绩字符串解析', () {
      expect(GpaCalculator.parseScore('92'), 92.0);
      expect(GpaCalculator.parseScore('优秀'), 95.0);
      expect(GpaCalculator.parseScore('良好'), 85.0);
      expect(GpaCalculator.parseScore('中等'), 75.0);
      expect(GpaCalculator.parseScore('及格'), 65.0);
      expect(GpaCalculator.parseScore('不及格'), 50.0);
    });

    test('多门课程加权 GPA 与平均分统计计算', () {
      final grades = [
        const GradeItem(
          id: 'g1',
          courseName: '高等数学',
          credit: 4,
          rawScore: '90',
          score: 90,
          gradePoint: 4,
        ),
        const GradeItem(
          id: 'g2',
          courseName: '大学英语',
          credit: 2,
          rawScore: '80',
          score: 80,
          gradePoint: 3,
        ),
      ];

      // HBU 模式：
      // 高等数学 (4 学分): 90分 -> 4.0绩点，加权绩点 = 16
      // 大学英语 (2 学分): 80分 -> (80-60)/10 + 1.0 = 3.0绩点，加权绩点 = 6
      // 总学分 = 6, 平均 GPA = (16 + 6) / 6 = 3.67
      // 加权均分 = (90 * 4 + 80 * 2) / 6 = (360 + 160) / 6 = 86.7
      final summary = GpaCalculator.calculate(
        grades: grades,
      );

      expect(summary.totalCredits, 6.0);
      expect(summary.passedCredits, 6.0);
      expect(summary.courseCount, 2);
      expect(summary.failedCoursesCount, 0);
      expect(summary.gpa, 3.67);
      expect(summary.weightedAverage, 86.7);
    });
  });
}
