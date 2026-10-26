import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/calendar/ics_exporter.dart';
import 'package:shiori/data/models/course.dart';

void main() {
  group('IcsExporter 导出 RFC 5545 日历测试', () {
    const exporter = IcsExporter();

    test('导出标准 VCALENDAR 与 VEVENT', () {
      final semesterStart = DateTime(2026, 9); // 星期二
      final courses = [
        const Course(
          id: 'test_course_1',
          name: '操作系统原理',
          teacher: '张老师',
          classroom: '计算机楼 301',
          dayOfWeek: 1, // 周一
          startPeriod: 1,
          endPeriod: 2,
          weeks: [1, 2],
        ),
      ];

      final ics = exporter.export(
        courses: courses,
        semesterStartDate: semesterStart,
      );

      expect(ics.contains('BEGIN:VCALENDAR'), isTrue);
      expect(ics.contains('VERSION:2.0'), isTrue);
      expect(ics.contains('X-WR-CALNAME:河北大学课程表'), isTrue);
      expect(ics.contains('SUMMARY:操作系统原理'), isTrue);
      expect(ics.contains('LOCATION:计算机楼 301'), isTrue);
      expect(ics.contains('BEGIN:VALARM'), isTrue);
      expect(ics.contains('END:VCALENDAR'), isTrue);

      // 周次为 [1, 2]，应生成 2 个 VEVENT
      final eventCount = RegExp('BEGIN:VEVENT').allMatches(ics).length;
      expect(eventCount, 2);
    });
  });
}
