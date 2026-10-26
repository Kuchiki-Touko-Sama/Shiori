import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:shiori/core/calculator/gpa_calculator.dart';
import 'package:shiori/data/models/grade.dart';

/// URP 历年成绩与本学期成绩解析器。
///
/// 支持解析现代 URP 的 JSON 成绩数据以及传统 HTML 表格。
class GradeParser {
  const GradeParser();

  /// 解析成绩数据（支持 JSON 与 HTML）
  List<GradeItem> parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return <GradeItem>[];

    // 1. 尝试直接作为 JSON 解析
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final jsonGrades = _parseJsonGrades(trimmed);
        if (jsonGrades.isNotEmpty) {
          return jsonGrades;
        }
      } on Exception {
        // 继续 HTML 解析
      }
    }

    // 2. 检查内嵌脚本 JSON
    final scriptJsonMatch = RegExp(
      r'(?:var|let|const)?\s*(?:scoreList|gradeList|cjList|scoreData)\s*=\s*([{\[].*?[}\]]);',
      dotAll: true,
    ).firstMatch(content);
    if (scriptJsonMatch != null) {
      try {
        final rawJson = scriptJsonMatch.group(1)!;
        final jsonGrades = _parseJsonGrades(rawJson);
        if (jsonGrades.isNotEmpty) {
          return jsonGrades;
        }
      } on Exception {
        // 脚本提取失败继续 HTML 解析
      }
    }

    // 3. 作为传统 HTML 表格解析
    final document = html_parser.parse(content);
    final grades = <GradeItem>[];

    final rows = document.querySelectorAll('table tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      // 成绩表格通常有 6 列以上
      if (cells.length < 5) continue;

      final rowText = row.text;
      // 过滤表头行
      if (rowText.contains('课程名称') ||
          rowText.contains('学分') ||
          rowText.contains('成绩') ||
          rowText.contains('序号')) {
        continue;
      }

      var semester = '';
      var courseName = '';
      var credit = 0.0;
      var rawScore = '';
      var gradePoint = 0.0;
      var courseType = '必修';
      var examType = '正常考试';

      for (var i = 0; i < cells.length; i++) {
        final text = cells[i].text
            .replaceAll('\u00A0', '')
            .replaceAll('&nbsp;', '')
            .trim();
        if (text.isEmpty) continue;

        // 识别学年学期（例如 2024-2025-1, 2025秋）
        if (RegExp(r'\d{4}[-~]\d{4}|\d{4}年').hasMatch(text)) {
          semester = text;
        } else if (text == '必修' ||
            text.contains('必修') ||
            text.contains('专选') ||
            text.contains('公选') ||
            text.contains('任选') ||
            text.contains('选修') ||
            text.contains('实践')) {
          courseType = text;
        } else if (text == '正常考试' ||
            text == '重修' ||
            text == '补考' ||
            text == '初考') {
          examType = text;
        } else if (RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
          final val = double.tryParse(text) ?? 0.0;
          // 若小于等于 10 通常为学分或绩点，在 (10, 100] 之间为百分制成绩，大于 100 为课程代码
          if (val > 10 && val <= 100 && rawScore.isEmpty) {
            rawScore = text;
          } else if (val <= 10 && credit == 0) {
            credit = val;
          } else if (val <= 5 && gradePoint == 0) {
            gradePoint = val;
          }
        } else if (text.contains('优') ||
            text.contains('良') ||
            text.contains('中') ||
            text.contains('及格')) {
          rawScore = text;
        } else if (courseName.isEmpty &&
            text.length > 1 &&
            !RegExp(r'^\d+$').hasMatch(text)) {
          courseName = text;
        }
      }

      if (courseName.isNotEmpty && rawScore.isNotEmpty) {
        final numericScore = double.tryParse(rawScore) ??
            GpaCalculator.parseScore(rawScore);

        grades.add(
          GradeItem(
            id: '${courseName}_${semester}_$rawScore',
            courseName: courseName,
            credit: credit > 0 ? credit : 2.0,
            rawScore: rawScore,
            score: numericScore,
            gradePoint: gradePoint > 0
                ? gradePoint
                : GpaCalculator.calculatePoint(numericScore, GpaAlgorithm.hbu4),
            courseType: courseType,
            semester: semester.isNotEmpty ? semester : '2026-2027-1',
            examType: examType,
          ),
        );
      }
    }

    return grades;
  }

  /// 解析 JSON 成绩列表
  List<GradeItem> _parseJsonGrades(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    final grades = <GradeItem>[];
    final items = <Map<String, dynamic>>[];

    void collect(dynamic data, [String? parentSemester]) {
      if (data is List) {
        for (final item in data) {
          collect(item, parentSemester);
        }
      } else if (data is Map<String, dynamic>) {
        final lnList = data['lnList'];
        if (lnList is List) {
          for (final term in lnList) {
            if (term is Map<String, dynamic>) {
              final termName = (term['cjlx'] ??
                      term['cjbh'] ??
                      term['zxjxjhh'] ??
                      '')
                  .toString();
              collect(term['cjList'], termName);
            }
          }
        } else if (data.containsKey('list') && data['list'] is List) {
          collect(data['list'], parentSemester);
        } else if (data.containsKey('scoreList') && data['scoreList'] is List) {
          collect(data['scoreList'], parentSemester);
        } else if (data.containsKey('cjList') && data['cjList'] is List) {
          collect(data['cjList'], parentSemester);
        } else if (data.containsKey('courseName') ||
            data.containsKey('kcm') ||
            data.containsKey('name')) {
          if (parentSemester != null && parentSemester.isNotEmpty) {
            data['_parentSemester'] = parentSemester;
          }
          items.add(data);
        }
      }
    }

    collect(decoded);

    for (final m in items) {
      final courseName = (m['courseName'] ?? m['kcm'] ?? m['name'] ?? '')
          .toString()
          .trim();
      if (courseName.isEmpty) continue;

      final rawScore = (m['courseScore'] ??
              m['cj'] ??
              m['zscj'] ??
              m['score'] ??
              m['gradeName'] ??
              '')
          .toString()
          .trim();
      if (rawScore.isEmpty) continue;

      final credit = (m['credit'] is num)
          ? (m['credit'] as num).toDouble()
          : (double.tryParse((m['credit'] ?? m['xf'] ?? '0').toString()) ??
              0.0);

      final numericScore = (m['courseScore'] is num)
          ? (m['courseScore'] as num).toDouble()
          : (double.tryParse(rawScore) ?? GpaCalculator.parseScore(rawScore));

      final gradePoint = (m['gradePointScore'] is num)
          ? (m['gradePointScore'] as num).toDouble()
          : (double.tryParse(
                  (m['gradePoint'] ?? m['jd'] ?? '').toString()) ??
              GpaCalculator.calculatePoint(numericScore, GpaAlgorithm.hbu4));

      var semester =
          (m['semester'] ?? m['_parentSemester'] ?? '').toString().trim();
      final year = m['academicYearCode']?.toString().trim() ?? '';
      final term = m['termName']?.toString().trim() ??
          m['termCode']?.toString().trim() ??
          '';
      if (year.isNotEmpty && term.isNotEmpty) {
        semester = '$year学年$term季学期';
      } else if (semester.isEmpty) {
        semester = year.isNotEmpty ? year : '2025-2026学年秋季学期';
      }

      final courseType = (m['courseAttributeName'] ??
              m['courseType'] ??
              m['kcxz'] ??
              m['coursePropertiesName'] ??
              '必修')
          .toString()
          .trim();
      var examType =
          (m['examTypeName'] ?? m['examType'] ?? '').toString().trim();
      if (examType.isEmpty) {
        if (m['makeupExaminationTypeCode'] != null &&
            m['makeupExaminationTypeCode'].toString().trim().isNotEmpty) {
          examType = '补考';
        } else if (m['examTypeCode'] == '01') {
          examType = '考试';
        } else if (m['examTypeCode'] == '02') {
          examType = '考查';
        } else {
          examType = '正常考试';
        }
      }

      grades.add(
        GradeItem(
          id: '${courseName}_${semester}_${grades.length}',
          courseName: courseName,
          credit: credit,
          rawScore: rawScore,
          score: numericScore,
          gradePoint: gradePoint,
          courseType: courseType,
          semester: semester,
          examType: examType,
        ),
      );
    }

    return grades;
  }
}
