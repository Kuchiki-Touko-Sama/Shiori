import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/parsers/grade_parser.dart';

void main() {
  group('GradeParser HTML 成绩解析测试', () {
    const parser = GradeParser();

    test('解析典型 URP 成绩表格 HTML', () {
      const sampleHtml = '''
      <html>
        <body>
          <table class="displayTag">
            <tr>
              <td>学年学期</td><td>课程号</td><td>课程名称</td><td>学分</td><td>课程属性</td><td>成绩</td><td>绩点</td>
            </tr>
            <tr>
              <td>2025-2026-1</td>
              <td>1001</td>
              <td>高等数学(上)</td>
              <td>4.5</td>
              <td>必修</td>
              <td>92</td>
              <td>4.0</td>
            </tr>
            <tr>
              <td>2025-2026-1</td>
              <td>1002</td>
              <td>大学英语(一)</td>
              <td>3.0</td>
              <td>必修</td>
              <td>良好</td>
              <td>3.5</td>
            </tr>
            <tr>
              <td>2025-2026-2</td>
              <td>1003</td>
              <td>数据结构与算法</td>
              <td>4.0</td>
              <td>必修</td>
              <td>88</td>
              <td>3.8</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final grades = parser.parse(sampleHtml);
      expect(grades.length, 3);

      final math = grades.firstWhere((g) => g.courseName.contains('高等数学'));
      expect(math.credit, 4.5);
      expect(math.score, 92.0);
      expect(math.rawScore, '92');
      expect(math.gradePoint, 4.0);
      expect(math.semester, '2025-2026-1');
      expect(math.courseType, '必修');
      expect(math.isPassed, isTrue);

      final english = grades.firstWhere((g) => g.courseName.contains('大学英语'));
      expect(english.credit, 3.0);
      expect(english.rawScore, '良好');
      expect(english.score, 85.0);
      expect(english.isPassed, isTrue);
    });

    test('解析现代 URP Ajax 返回的 JSON 格式成绩数据', () {
      const sampleJson = '''
      {
        "list": [
          {
            "courseName": "离散数学",
            "credit": 3.5,
            "score": "89",
            "gradePoint": 3.9,
            "semester": "2025-2026-1",
            "courseType": "必修",
            "examType": "正常考试"
          },
          {
            "courseName": "计算机组成原理",
            "credit": 4.0,
            "score": "95",
            "gradePoint": 4.0,
            "semester": "2025-2026-1",
            "courseType": "必修",
            "examType": "正常考试"
          }
        ]
      }
      ''';

      final grades = parser.parse(sampleJson);
      expect(grades.length, 2);

      final dm = grades.firstWhere((g) => g.courseName == '离散数学');
      expect(dm.credit, 3.5);
      expect(dm.score, 89.0);
      expect(dm.gradePoint, 3.9);
      expect(dm.isPassed, isTrue);
    });
  });
}
