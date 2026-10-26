import 'package:shiori/data/models/course.dart';

/// 校园标准作息节次时间表（默认配置）。
const Map<int, ({int startHour, int startMinute, int endHour, int endMinute})>
    kDefaultBellSchedule = {
  1: (startHour: 8, startMinute: 0, endHour: 8, endMinute: 45),
  2: (startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),
  3: (startHour: 10, startMinute: 0, endHour: 10, endMinute: 45),
  4: (startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
  5: (startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),
  6: (startHour: 14, startMinute: 55, endHour: 15, endMinute: 40),
  7: (startHour: 16, startMinute: 0, endHour: 16, endMinute: 45),
  8: (startHour: 16, startMinute: 55, endHour: 17, endMinute: 40),
  9: (startHour: 19, startMinute: 0, endHour: 19, endMinute: 45),
  10: (startHour: 19, startMinute: 55, endHour: 20, endMinute: 40),
  11: (startHour: 20, startMinute: 50, endHour: 21, endMinute: 35),
  12: (startHour: 21, startMinute: 45, endHour: 22, endMinute: 30),
};

/// RFC 5545 标准 iCalendar (.ics) 日历导出器。
class IcsExporter {
  const IcsExporter();

  /// 把课程列表导出为 .ics 格式文本。
  ///
  /// [semesterStartDate] 必须是第一周的周一。
  String export({
    required List<Course> courses,
    required DateTime semesterStartDate,
    Map<int, ({int startHour, int startMinute, int endHour, int endMinute})>
        bellSchedule = kDefaultBellSchedule,
    int advanceReminderMinutes = 20,
  }) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Shiori//HBU Schedule//CN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('X-WR-CALNAME:河北大学课程表');

    for (final course in courses) {
      for (final week in course.weeks) {
        // 计算当天日期：第一周周一 + (周次-1)*7 + (星期几-1)
        final courseDate = semesterStartDate.add(
          Duration(days: (week - 1) * 7 + (course.dayOfWeek - 1)),
        );

        final startBell = bellSchedule[course.startPeriod] ??
            (
              startHour: 8 + (course.startPeriod - 1),
              startMinute: 0,
              endHour: 8 + (course.startPeriod - 1),
              endMinute: 45,
            );

        final endBell = bellSchedule[course.endPeriod] ?? startBell;

        final startDt = DateTime(
          courseDate.year,
          courseDate.month,
          courseDate.day,
          startBell.startHour,
          startBell.startMinute,
        );

        final endDt = DateTime(
          courseDate.year,
          courseDate.month,
          courseDate.day,
          endBell.endHour,
          endBell.endMinute,
        );

        final uid =
            '${course.id}_w${week}_d${course.dayOfWeek}_p${course.startPeriod}@shiori.dev';

        buffer
          ..writeln('BEGIN:VEVENT')
          ..writeln('UID:$uid')
          ..writeln('DTSTAMP:${_formatDateTime(DateTime.now())}')
          ..writeln('DTSTART:${_formatDateTime(startDt)}')
          ..writeln('DTEND:${_formatDateTime(endDt)}')
          ..writeln('SUMMARY:${_escape(course.name)}')
          ..writeln('LOCATION:${_escape(course.classroom)}')
          ..writeln(
            'DESCRIPTION:${_escape('教师: ${course.teacher}\n节次: 第${course.startPeriod}-${course.endPeriod}节\n周次: 第$week周')}',
          );

        if (advanceReminderMinutes > 0) {
          buffer
            ..writeln('BEGIN:VALARM')
            ..writeln('ACTION:DISPLAY')
            ..writeln('DESCRIPTION:上课提醒：${_escape(course.name)}')
            ..writeln('TRIGGER:-PT${advanceReminderMinutes}M')
            ..writeln('END:VALARM');
        }

        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// 格式化为 iCalendar 紧凑时间字符串 YYYYMMDDTHHmmSS
  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min$s';
  }

  /// 转义 iCalendar 特殊字符
  String _escape(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }
}
