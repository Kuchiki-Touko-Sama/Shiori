import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/parsers/exam_parser.dart';

void main() {
  group('ExamParser 考试安排解析测试', () {
    const parser = ExamParser();

    test('解析典型 URP 考试安排表格 HTML', () {
      const sampleHtml = '''
      <html>
        <body>
          <table id="user">
            <tr>
              <td>序号</td><td>课程名称</td><td>考试时间</td><td>考试地点</td><td>座位号</td><td>形式</td>
            </tr>
            <tr>
              <td>1</td>
              <td>大学英语(三)</td>
              <td>2026-11-20 09:00 - 11:00</td>
              <td>七教 301</td>
              <td>28</td>
              <td>期末考试</td>
            </tr>
            <tr>
              <td>2</td>
              <td>高等数学(上)</td>
              <td>2026-11-25 14:30 - 16:30</td>
              <td>二教 105</td>
              <td>12</td>
              <td>期末考试</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final exams = parser.parse(sampleHtml);
      expect(exams.length, 2);

      final english = exams.first;
      expect(english.courseName, '大学英语(三)');
      expect(english.location, '七教 301');
      expect(english.seatNumber, '28');
      expect(english.examDate, '2026-11-20');
      expect(english.parsedDateTime, isNotNull);
      expect(english.parsedDateTime!.hour, 9);

      final math = exams[1];
      expect(math.courseName, '高等数学(上)');
      expect(math.seatNumber, '12');
      expect(math.parsedDateTime!.hour, 14);
      expect(math.parsedDateTime!.minute, 30);
    });
  });
}
