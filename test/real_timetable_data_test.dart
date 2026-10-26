import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/parsers/exam_parser.dart';
import 'package:shiori/data/parsers/timetable_parser.dart';

void main() {
  group('Real Timetable Data Parsing Test', () {
    test('对齐河北大学真实返回的完整课表 JSON 数据', () {
      final file = File('test/fixtures/real_timetable.json');
      expect(file.existsSync(), isTrue, reason: '必须存在 real_timetable.json 文件');
      final jsonString = file.readAsStringSync();

      const parser = TimetableParser();
      final courses = parser.parse(jsonString);

      // 验证课程条目总数：9 门已排课课程共 16 个具体上课时段
      expect(courses.length, 16);

      // 所有时段的唯一 ID 必须完全不重复
      final ids = courses.map((c) => c.id).toSet();
      expect(ids.length, courses.length);

      final names = courses.map((c) => c.name).toSet();

      // 核心必有课程断言
      expect(names.contains('嵌入式系统'), isTrue);
      expect(names.contains('超越体育'), isTrue);
      expect(names.contains('大学生职业生涯规划（行动体验）'), isTrue);
      expect(names.contains('中华民族共同体概论'), isTrue);
      expect(names.contains('智能仪表与工业总线'), isTrue);
      expect(names.contains('形势与政策7'), isTrue);
      expect(names.contains('自动化专业英语'), isTrue);
      expect(names.contains('工程数学A'), isTrue);
      expect(names.contains('电路分析基础'), isTrue);

      // 验证无排课实验/实习类课程未被虚假塞入周一1-2节
      expect(names.contains('嵌入式系统实验'), isFalse);
      expect(names.contains('生产实习'), isFalse);
      expect(names.contains('数据结构实验'), isFalse);

      // 验证具体的排课细节（嵌入式系统：3个时段，学分2.0，教师田华，教室D3座 315）
      final embeddedCourses = courses.where((c) => c.name == '嵌入式系统').toList();
      expect(embeddedCourses.length, 3);
      expect(embeddedCourses.first.teacher, '田华');
      expect(embeddedCourses.first.classroom, 'D3座 315');
      expect(embeddedCourses.first.credit, 2.0);
      expect(embeddedCourses[0].dayOfWeek, 1);
      expect(embeddedCourses[0].startPeriod, 5);
      expect(embeddedCourses[0].endPeriod, 6);
      expect(embeddedCourses[1].dayOfWeek, 3);
      expect(embeddedCourses[1].startPeriod, 5);
      expect(embeddedCourses[1].endPeriod, 6);
      expect(embeddedCourses[2].dayOfWeek, 4);
      expect(embeddedCourses[2].startPeriod, 7);
      expect(embeddedCourses[2].endPeriod, 8);

      // 验证工程数学A（4个时段，学分4.0）
      final mathCourses = courses.where((c) => c.name == '工程数学A').toList();
      expect(mathCourses.length, 4);
      expect(mathCourses.first.teacher, '付磊');
      expect(mathCourses.first.credit, 4.0);

      // 验证跨多小节课程（如中华民族共同体概论，连上4节：1-4节）
      final generalCourse = courses.firstWhere((c) => c.name == '中华民族共同体概论');
      expect(generalCourse.dayOfWeek, 6);
      expect(generalCourse.startPeriod, 1);
      expect(generalCourse.endPeriod, 4);
      expect(generalCourse.credit, 2.0);
    });

    test('xkxx 字典形式且无 dateList 时亦能准确解析', () {
      const sampleXkxxJson = '''
      {
        "xkxx": [
          {
            "COURSE_01": {
              "courseName": "自动控制原理",
              "attendClassTeacher": "李教授*",
              "unit": 3.5,
              "timeAndPlaceList": [
                {
                  "classDay": 2,
                  "classSessions": 3,
                  "continuingSession": 2,
                  "teachingBuildingName": "第九教学楼",
                  "classroomName": "101",
                  "classWeek": "111111110000000000000000"
                }
              ]
            }
          }
        ]
      }
      ''';

      const parser = TimetableParser();
      final courses = parser.parse(sampleXkxxJson);
      expect(courses.length, 1);
      expect(courses.first.name, '自动控制原理');
      expect(courses.first.teacher, '李教授');
      expect(courses.first.credit, 3.5);
      expect(courses.first.dayOfWeek, 2);
      expect(courses.first.startPeriod, 3);
      expect(courses.first.endPeriod, 4);
      expect(courses.first.classroom, '第九教学楼 101');
      expect(courses.first.weeks, [1, 2, 3, 4, 5, 6, 7, 8]);
    });
  });

  group('ExamParser JSON 支持测试', () {
    test('解析现代 URP 考试 JSON 数据', () {
      const sampleExamJson = '''
      {
        "data": [
          {
            "courseName": "嵌入式系统",
            "examTime": "2026-12-25 09:00-11:00",
            "classroomName": "D3座 315",
            "seatNumber": "28",
            "examType": "期末考试"
          },
          {
            "courseName": "电路分析基础",
            "examTime": "2026-12-28 14:00-16:00",
            "classroomName": "A2座 501",
            "seatNumber": "15",
            "examType": "期末考试"
          }
        ]
      }
      ''';

      const examParser = ExamParser();
      final exams = examParser.parse(sampleExamJson);
      expect(exams.length, 2);
      expect(exams.first.courseName, '嵌入式系统');
      expect(exams.first.examDate, '2026-12-25');
      expect(exams.first.location, 'D3座 315');
      expect(exams.first.seatNumber, '28');

      expect(exams.last.courseName, '电路分析基础');
      expect(exams.last.seatNumber, '15');
    });
  });
}
