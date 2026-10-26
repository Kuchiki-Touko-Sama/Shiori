import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shiori/data/models/course.dart';

/// URP 课表解析器。
///
/// 支持解析 URP 高校教务系统现代 Ajax/JSON 格式、内嵌脚本数据，
/// 以及传统 HTML 课表网格与课程清单。
class TimetableParser {
  const TimetableParser();

  /// 解析课表（支持 JSON 格式与传统 HTML 格式）。
  List<Course> parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return <Course>[];

    // 1. 优先尝试直接作为 JSON 解析（新版现代 URP /ajaxStudentSchedule 返回格式）
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final jsonResult = _parseJsonContent(trimmed);
        if (jsonResult.isNotEmpty) {
          return _assignColorIndices(jsonResult);
        }
      } on Exception {
        // 非纯 JSON 则继续尝试内嵌脚本或 HTML 表格
      }
    }

    // 2. 检查 HTML 中是否包含内嵌的 JSON 数据（如 <script> 标签中的 scheduleList/dateList/xkxx）
    final scriptJsonMatch = RegExp(
      r'(?:var|let|const)?\s*(?:scheduleData|courseData|dateList|selectCourseList|scheduleList|xkxx)\s*=\s*([{\[].*?[}\]]);',
      dotAll: true,
    ).firstMatch(content);
    if (scriptJsonMatch != null) {
      try {
        final rawJson = scriptJsonMatch.group(1)!;
        final jsonResult = _parseJsonContent(rawJson);
        if (jsonResult.isNotEmpty) {
          return _assignColorIndices(jsonResult);
        }
      } on Exception {
        // 脚本提取失败继续常规解析
      }
    }

    // 3. 作为传统 HTML 表格解析（传统 URP 与网页直出）
    final document = html_parser.parse(content);

    // 优先尝试解析老版 URP 课表格子（table#user / table.title-top-1）
    final gridCourses = _parseGridTable(document);
    if (gridCourses.isNotEmpty) {
      return gridCourses;
    }

    // 尝试解析新版 URP / 列表形式的课程表
    final listCourses = _parseListTable(document);
    if (listCourses.isNotEmpty) {
      return listCourses;
    }

    return <Course>[];
  }

  /// 解析网格式课表（行=节次，列=星期一至星期日）
  List<Course> _parseGridTable(Document doc) {
    final courses = <Course>[];
    final tables = doc.querySelectorAll('table');

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      // 课表通常有较多行（至少对应大节或小节）
      if (rows.length < 5) continue;

      var currentPeriodIndex = 1;
      for (final row in rows) {
        final rowText = row.text;
        // 过滤表头行
        if (rowText.contains('周一') ||
            rowText.contains('星期一') ||
            row.querySelector('th') != null) {
          continue;
        }

        final cells = row.querySelectorAll('td');
        if (cells.length < 7) continue;

        // 检查是否有行头标记节次
        final firstText = cells.first.text.trim();
        final periodMatch = RegExp(r'(\d+)').firstMatch(firstText);
        if (periodMatch != null) {
          final p = int.tryParse(periodMatch.group(1)!);
          if (p != null) currentPeriodIndex = p;
        }

        // 列：星期一(1) 到 星期日(7)
        // 排除第一列（时间/节次列）
        final startCol = cells.length > 7 ? cells.length - 7 : 0;
        for (var colIdx = startCol; colIdx < cells.length; colIdx++) {
          final dayOfWeek = colIdx - startCol + 1;
          if (dayOfWeek < 1 || dayOfWeek > 7) continue;

          final cell = cells[colIdx];
          final text = cell.text
              .replaceAll('\u00A0', '')
              .replaceAll('&nbsp;', '')
              .trim();
          if (text.isEmpty) continue;

          final parsedInCell = _parseCellContent(
            cell,
            dayOfWeek: dayOfWeek,
            fallbackPeriod: currentPeriodIndex,
          );
          courses.addAll(parsedInCell);
        }

        currentPeriodIndex += 2; // 默认大节每次跨 2 节
      }

      if (courses.isNotEmpty) break;
    }

    return _assignColorIndices(courses);
  }

  /// 解析单元格内的多行课程信息
  List<Course> _parseCellContent(
    Element cell, {
    required int dayOfWeek,
    required int fallbackPeriod,
  }) {
    final courses = <Course>[];
    // 单元格内可能通过 <br>、<hr> 分隔同一时段的多门课（单双周课）
    final html = cell.innerHtml;
    final segments = html.split(RegExp(r'<hr[^>]*>|<br\s*/?>\s*<br\s*/?>'));

    for (var seg in segments) {
      seg = seg
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp('<[^>]*>'), '')
          .trim();
      if (seg.isEmpty) continue;

      final lines = seg
          .split('\n')
          .map((l) => l.replaceAll('\u00A0', '').replaceAll('&nbsp;', '').trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isEmpty) continue;

      final courseName = lines.first;
      if (courseName == '时间' ||
          courseName.startsWith('周') ||
          courseName.startsWith('星期')) {
        continue;
      }
      var teacher = '';
      var classroom = '';
      var weeks = <int>[];
      var startPeriod = fallbackPeriod;
      var endPeriod = fallbackPeriod + 1;

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];

        // 尝试解析周次
        if (line.contains('周')) {
          final parsedWeeks = parseWeekString(line);
          if (parsedWeeks.isNotEmpty) {
            weeks = parsedWeeks;
          }
        }

        // 尝试解析节次 [1-2节]
        final periodRange = parsePeriod(line);
        if (periodRange != null) {
          startPeriod = periodRange.start;
          endPeriod = periodRange.end;
        }

        // 优先识别教师称谓
        if (line.contains('老师') ||
            line.contains('教授') ||
            line.contains('讲师') ||
            line.contains('助教')) {
          teacher = line;
        } else if (RegExp(r'\d+教|教\d+|教学楼|[A-Za-z]\d+|[0-9]{3,}|\d+室|实验楼').hasMatch(line) ||
            line.contains('楼') ||
            line.contains('室') ||
            line.contains('机房')) {
          classroom = line;
        } else if (teacher.isEmpty &&
            !line.contains('周') &&
            !line.contains('节')) {
          teacher = line;
        }
      }

      // 如果未解析出特定周次，默认全学期 1-16 周
      if (weeks.isEmpty) {
        weeks = List<int>.generate(16, (i) => i + 1);
      }

      final id = '${courseName}_${dayOfWeek}_$startPeriod';
      courses.add(
        Course(
          id: id,
          name: courseName,
          teacher: teacher,
          classroom: classroom,
          dayOfWeek: dayOfWeek,
          startPeriod: startPeriod,
          endPeriod: endPeriod,
          weeks: weeks,
          rawTimeStr: seg,
        ),
      );
    }

    return courses;
  }

  /// 解析列表式（清单式）课程表格
  List<Course> _parseListTable(Document doc) {
    final courses = <Course>[];
    final rows = doc.querySelectorAll('table tr');

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 5) continue;

      // 清单表特征通常包含：课程名、教师、周次、时间地点
      final textJoined = row.text;
      if (!textJoined.contains('周')) continue;

      // 尝试按列抽取
      final name = cells[1].text.trim();
      final teacher = cells.length > 2 ? cells[2].text.trim() : '';
      final timeAndPlace = cells.length > 4 ? cells[4].text.trim() : '';

      final weeks = parseWeekString(timeAndPlace);
      final periodRange = parsePeriod(timeAndPlace);
      final dayOfWeek = _parseDayOfWeek(timeAndPlace);
      final startPeriod = periodRange?.start ?? 1;
      final endPeriod = periodRange?.end ?? 2;

      if (name.isNotEmpty && weeks.isNotEmpty) {
        courses.add(
          Course(
            id: '${name}_${dayOfWeek}_$startPeriod',
            name: name,
            teacher: teacher,
            dayOfWeek: dayOfWeek,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weeks: weeks,
            rawTimeStr: timeAndPlace,
          ),
        );
      }
    }

    return _assignColorIndices(courses);
  }

  /// 解析周次字符串，例如：
  /// - `1-16周` -> 1..16
  /// - `1-16周(单)` -> 1, 3, 5, ..., 15
  /// - `2-16周(双)` -> 2, 4, 6, ..., 16
  /// - `1-8,10-17周` -> 1..8 与 10..17
  /// - `第5周` -> 5
  static List<int> parseWeekString(String text) {
    final weeks = <int>{};
    final isOddOnly = text.contains('(单)') || text.contains('单周');
    final isEvenOnly = text.contains('(双)') || text.contains('双周');

    // 匹配如 1-16, 1-8, 10
    final rangeRegex = RegExp(r'(\d+)(?:\s*-\s*(\d+))?');
    final matches = rangeRegex.allMatches(text);

    for (final match in matches) {
      final start = int.tryParse(match.group(1) ?? '') ?? 0;
      final endStr = match.group(2);
      final end = endStr != null ? (int.tryParse(endStr) ?? start) : start;

      if (start <= 0) continue;
      for (var w = start; w <= end; w++) {
        if (isOddOnly && w.isEven) continue;
        if (isEvenOnly && w.isOdd) continue;
        weeks.add(w);
      }
    }

    final sorted = weeks.toList()..sort();
    return sorted;
  }

  /// 解析节次，例如 `[1-2节]`、`3-4节`、`第1-2节`
  static ({int start, int end})? parsePeriod(String text) {
    if (!text.contains('节')) return null;
    final match = RegExp(r'(?:\[|第)?(\d+)\s*-\s*(\d+)\s*节?').firstMatch(text);
    if (match != null) {
      final start = int.tryParse(match.group(1)!) ?? 1;
      final end = int.tryParse(match.group(2)!) ?? start;
      return (start: start, end: end);
    }
    return null;
  }

  /// 从文本中提取星期几（1..7）
  static int _parseDayOfWeek(String text) {
    if (text.contains('周一') || text.contains('星期一')) return 1;
    if (text.contains('周二') || text.contains('星期二')) return 2;
    if (text.contains('周三') || text.contains('星期三')) return 3;
    if (text.contains('周四') || text.contains('星期四')) return 4;
    if (text.contains('周五') || text.contains('星期五')) return 5;
    if (text.contains('周六') || text.contains('星期六')) return 6;
    if (text.contains('周日') || text.contains('星期日') || text.contains('周天')) {
      return 7;
    }
    return 1;
  }

  /// 解析新版现代 URP 的 JSON 课表结构
  List<Course> _parseJsonContent(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    final courses = <Course>[];

    // 收集所有可能的课程条目
    final rawCourseItems = <Map<String, dynamic>>[];

    void collectItems(dynamic data) {
      if (data is List) {
        data.forEach(collectItems);
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('selectCourseList') &&
            data['selectCourseList'] is List) {
          collectItems(data['selectCourseList']);
        } else if (data.containsKey('dateList') && data['dateList'] is List) {
          collectItems(data['dateList']);
        } else if (data.containsKey('xkxx')) {
          final xkxx = data['xkxx'];
          if (xkxx is List) {
            for (final item in xkxx) {
              if (item is Map<String, dynamic>) {
                item.values.forEach(collectItems);
              } else {
                collectItems(item);
              }
            }
          } else if (xkxx is Map<String, dynamic>) {
            xkxx.values.forEach(collectItems);
          }
        } else if (data.containsKey('courseList') &&
            data['courseList'] is List) {
          collectItems(data['courseList']);
        } else if (data.containsKey('scheduleList') &&
            data['scheduleList'] is List) {
          collectItems(data['scheduleList']);
        } else if (data.containsKey('courseName') ||
            data.containsKey('coureName') ||
            data.containsKey('kcm') ||
            data.containsKey('name')) {
          rawCourseItems.add(data);
        }
      }
    }

    collectItems(decoded);

    for (final cMap in rawCourseItems) {
      final name = (cMap['courseName'] ??
              cMap['coureName'] ??
              cMap['kcm'] ??
              cMap['name'] ??
              '')
          .toString()
          .trim();
      if (name.isEmpty) continue;

      final teacher = (cMap['attendClassTeacher'] ??
              cMap['teacher'] ??
              cMap['jsm'] ??
              '')
          .toString()
          .replaceAll('*', '')
          .trim();

      final credit = (cMap['unit'] is num)
          ? (cMap['unit'] as num).toDouble()
          : double.tryParse((cMap['unit'] ?? cMap['credit'] ?? cMap['xf'] ?? '0').toString()) ??
              0.0;

      // 提取排课时间与地点列表（timeAndPlaceList）
      final dynamic tpList = cMap['timeAndPlaceList'] ??
          cMap['sjd'] ??
          cMap['scheduleList'];

      if (tpList is List && tpList.isNotEmpty) {
        for (final tp in tpList) {
          if (tp is! Map<String, dynamic>) continue;

          // 星期解析 (1..7)
          final dayRaw = tp['classDay'] ?? tp['dayOfWeek'] ?? tp['day'];
          var dayOfWeek = 1;
          if (dayRaw is int) {
            dayOfWeek = (dayRaw >= 1 && dayRaw <= 7) ? dayRaw : 1;
          } else if (dayRaw != null) {
            dayOfWeek = _parseDayOfWeek(dayRaw.toString());
          }

          // 节次解析
          final startPeriod = int.tryParse((tp['classSessions'] ??
                      tp['startSession'] ??
                      tp['session'] ??
                      '1')
                  .toString()) ??
              1;
          final duration = int.tryParse((tp['continuingSession'] ??
                      tp['step'] ??
                      '2')
                  .toString()) ??
              2;
          final endPeriod = startPeriod + duration - 1;

          // 教室与教学楼
          final bldg = (tp['teachingBuildingName'] ??
                  tp['building'] ??
                  '')
              .toString()
              .trim();
          final room = (tp['classroomName'] ??
                  tp['classRoomName'] ??
                  tp['room'] ??
                  '')
              .toString()
              .trim();
          final classroom = (bldg.isNotEmpty && !room.contains(bldg))
              ? '$bldg $room'
              : (room.isNotEmpty ? room : bldg);

          // 周次解析
          final weekRaw = (tp['classWeek'] ??
                  tp['allWeeks'] ??
                  tp['weeks'] ??
                  '')
              .toString()
              .trim();
          var weeks = <int>[];
          if (weekRaw.length >= 10 && RegExp(r'^[01]+$').hasMatch(weekRaw)) {
            weeks = parseWeekBitmap(weekRaw);
          } else if (weekRaw.isNotEmpty) {
            weeks = parseWeekString(weekRaw);
          }
          if (weeks.isEmpty) {
            weeks = List<int>.generate(16, (i) => i + 1);
          }

          final id = '${name}_${dayOfWeek}_${startPeriod}_${courses.length}';
          courses.add(
            Course(
              id: id,
              name: name,
              teacher: teacher,
              classroom: classroom,
              dayOfWeek: dayOfWeek,
              startPeriod: startPeriod,
              endPeriod: endPeriod,
              weeks: weeks,
              credit: credit,
              rawTimeStr: weekRaw,
            ),
          );
        }
      } else {
        // 检查 cMap 本身是否是扁平的单条排课条目（包含明确的星期与节次信息）
        final hasExplicitSchedule = cMap.containsKey('classDay') ||
            cMap.containsKey('dayOfWeek') ||
            cMap.containsKey('classSessions') ||
            cMap.containsKey('startSession') ||
            (cMap['sksj'] != null &&
                cMap['sksj'].toString().trim().isNotEmpty);

        if (hasExplicitSchedule) {
          final dayRaw = cMap['classDay'] ?? cMap['dayOfWeek'] ?? cMap['day'];
          final dayOfWeek = (dayRaw is int && dayRaw >= 1 && dayRaw <= 7)
              ? dayRaw
              : _parseDayOfWeek(dayRaw?.toString() ?? cMap.toString());
          final startPeriod = int.tryParse(
                  (cMap['classSessions'] ?? cMap['startSession'] ?? '1')
                      .toString()) ??
              1;
          final duration = int.tryParse(
                  (cMap['continuingSession'] ?? cMap['step'] ?? '2')
                      .toString()) ??
              2;
          final endPeriod = startPeriod + duration - 1;
          final classroom =
              (cMap['classroomName'] ?? cMap['room'] ?? '').toString().trim();
          final weekRaw =
              (cMap['classWeek'] ?? cMap['weeks'] ?? '').toString().trim();
          var weeks = <int>[];
          if (weekRaw.length >= 10 && RegExp(r'^[01]+$').hasMatch(weekRaw)) {
            weeks = parseWeekBitmap(weekRaw);
          } else if (weekRaw.isNotEmpty) {
            weeks = parseWeekString(weekRaw);
          }
          if (weeks.isEmpty) {
            weeks = List<int>.generate(16, (i) => i + 1);
          }

          courses.add(
            Course(
              id: '${name}_${dayOfWeek}_${startPeriod}_${courses.length}',
              name: name,
              teacher: teacher,
              classroom: classroom,
              dayOfWeek: dayOfWeek,
              startPeriod: startPeriod,
              endPeriod: endPeriod,
              weeks: weeks,
              credit: credit,
              rawTimeStr: weekRaw,
            ),
          );
        }
        // 若无排课时间地点（如纯培养方案中的无排课实习/实验课程），不强行生成假的周一课表格子，保持网格整洁真实
      }
    }

    return courses;
  }

  /// 解析二进制位图周次字符串（如 "11111111111111110000" 代表前 16 周有课）
  static List<int> parseWeekBitmap(String bitmap) {
    final weeks = <int>[];
    for (var i = 0; i < bitmap.length; i++) {
      if (bitmap[i] == '1') {
        weeks.add(i + 1);
      }
    }
    return weeks;
  }

  /// 为同一名称的课程分配相同且和谐的色彩索引
  List<Course> _assignColorIndices(List<Course> courses) {
    final nameToColor = <String, int>{};
    var nextColor = 0;

    return courses.map((course) {
      final color = nameToColor.putIfAbsent(course.name, () {
        final c = nextColor;
        nextColor = (nextColor + 1) % 8;
        return c;
      });
      return course.copyWith(colorIndex: color);
    }).toList();
  }
}
