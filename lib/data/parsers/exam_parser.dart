import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:shiori/data/models/exam.dart';

/// URP 考试安排 HTML 与 JSON 解析器。
class ExamParser {
  const ExamParser();

  /// 解析考试安排（支持 JSON 与 HTML）
  List<ExamItem> parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return <ExamItem>[];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final jsonExams = _parseJsonContent(trimmed);
        if (jsonExams.isNotEmpty) return jsonExams;
      } on Exception {
        // Fallback to HTML
      }
    }

    final document = html_parser.parse(trimmed);
    final exams = <ExamItem>[];

    final rows = document.querySelectorAll('table tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      // 考试表通常有 5 列以上
      if (cells.length < 4) continue;

      final rowText = row.text;
      // 过滤表头行
      if (rowText.contains('课程名称') ||
          rowText.contains('考试时间') ||
          rowText.contains('序号')) {
        continue;
      }

      // 提取字段（兼容新老 URP 的不同列顺序）
      var courseName = '';
      var examTimeStr = '';
      var location = '';
      var seatNumber = '';
      var examType = '期末考试';

      // 遍历单元格，按模式识别内容
      for (var i = 0; i < cells.length; i++) {
        final text = cells[i].text.trim();
        if (text.isEmpty || text == '&nbsp;') continue;

        // 日期时间识别（包含 YYYY-MM-DD 或冒号时间）
        if (RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}').hasMatch(text) ||
            RegExp(r'\d{1,2}:\d{2}').hasMatch(text)) {
          examTimeStr = text;
        } else if (text.contains('楼') ||
            text.contains('教') ||
            text.contains('室') ||
            text.contains('机房')) {
          location = text;
        } else if (RegExp(r'^\d{1,3}$').hasMatch(text) && i > 3) {
          // 在后部出现的纯小数字通常是座位号
          seatNumber = text;
        } else if (text == '期末' ||
            text == '期末考试' ||
            text == '补考' ||
            text == '重修') {
          examType = text;
        } else if (courseName.isEmpty &&
            text.length > 1 &&
            !RegExp(r'^\d+$').hasMatch(text)) {
          courseName = text;
        }
      }

      if (courseName.isNotEmpty && examTimeStr.isNotEmpty) {
        final parsedDate = _parseExamDateTime(examTimeStr);
        final datePart = parsedDate != null
            ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
            : examTimeStr;

        exams.add(
          ExamItem(
            id: '${courseName}_$examTimeStr',
            courseName: courseName,
            examDate: datePart,
            examTime: examTimeStr,
            location: location,
            seatNumber: seatNumber,
            examType: examType,
            parsedDateTime: parsedDate,
          ),
        );
      }
    }

    // 按考试日期先后升序排序
    exams.sort((a, b) {
      if (a.parsedDateTime == null) return 1;
      if (b.parsedDateTime == null) return -1;
      return a.parsedDateTime!.compareTo(b.parsedDateTime!);
    });

    return exams;
  }

  /// 从形如 "2026-11-20 09:00-11:00" 中解析起始 DateTime
  DateTime? _parseExamDateTime(String timeStr) {
    try {
      final dateMatch =
          RegExp(r'(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})').firstMatch(timeStr);
      if (dateMatch == null) return null;

      final year = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final day = int.parse(dateMatch.group(3)!);

      var hour = 9;
      var minute = 0;
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
      if (timeMatch != null) {
        hour = int.parse(timeMatch.group(1)!);
        minute = int.parse(timeMatch.group(2)!);
      }

      return DateTime(year, month, day, hour, minute);
    } on Exception {
      return null;
    }
  }

  /// 解析新版现代 URP 考试 JSON 结构
  List<ExamItem> _parseJsonContent(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    final exams = <ExamItem>[];
    final items = <Map<String, dynamic>>[];

    void collect(dynamic data) {
      if (data is List) {
        data.forEach(collect);
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is List) {
          collect(data['data']);
        } else if (data.containsKey('root') && data['root'] is List) {
          collect(data['root']);
        } else if (data.containsKey('examList') && data['examList'] is List) {
          collect(data['examList']);
        } else if (data.containsKey('dateList') && data['dateList'] is List) {
          collect(data['dateList']);
        } else if (data.containsKey('courseName') ||
            data.containsKey('kcm') ||
            data.containsKey('examName')) {
          items.add(data);
        }
      }
    }

    collect(decoded);

    for (final item in items) {
      final courseName = (item['courseName'] ??
              item['kcm'] ??
              item['examName'] ??
              '')
          .toString()
          .trim();
      final examTimeStr = (item['examTime'] ??
              item['kssj'] ??
              item['time'] ??
              '')
          .toString()
          .trim();
      final location = (item['location'] ??
              item['classroomName'] ??
              item['ksdd'] ??
              item['room'] ??
              '')
          .toString()
          .trim();
      final seatNumber = (item['seatNumber'] ??
              item['zwh'] ??
              item['seat'] ??
              '')
          .toString()
          .trim();
      final examType = (item['examType'] ?? item['kslx'] ?? '期末考试')
          .toString()
          .trim();

      if (courseName.isNotEmpty && examTimeStr.isNotEmpty) {
        final parsedDate = _parseExamDateTime(examTimeStr);
        final datePart = parsedDate != null
            ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
            : examTimeStr;

        exams.add(
          ExamItem(
            id: '${courseName}_$examTimeStr',
            courseName: courseName,
            examDate: datePart,
            examTime: examTimeStr,
            location: location,
            seatNumber: seatNumber,
            examType: examType,
            parsedDateTime: parsedDate,
          ),
        );
      }
    }

    exams.sort((a, b) {
      if (a.parsedDateTime == null) return 1;
      if (b.parsedDateTime == null) return -1;
      return a.parsedDateTime!.compareTo(b.parsedDateTime!);
    });

    return exams;
  }
}
