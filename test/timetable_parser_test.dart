import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/parsers/timetable_parser.dart';

void main() {
  group('TimetableParser 周次与节次解析测试', () {
    test('标准周次范围 1-16周 解析', () {
      final weeks = TimetableParser.parseWeekString('1-16周');
      expect(weeks.length, 16);
      expect(weeks.first, 1);
      expect(weeks.last, 16);
    });

    test('单周解析 1-16周(单)', () {
      final weeks = TimetableParser.parseWeekString('1-16周(单)');
      expect(weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
    });

    test('双周解析 2-16周(双)', () {
      final weeks = TimetableParser.parseWeekString('2-16周(双)');
      expect(weeks, [2, 4, 6, 8, 10, 12, 14, 16]);
    });

    test('跨段周次 1-8,10-16周', () {
      final weeks = TimetableParser.parseWeekString('1-8,10-16周');
      expect(weeks.contains(9), isFalse);
      expect(weeks.contains(8), isTrue);
      expect(weeks.contains(10), isTrue);
      expect(weeks.length, 15);
    });

    test('节次范围 [1-2节] 解析', () {
      final period = TimetableParser.parsePeriod('高等数学[1-2节]');
      expect(period?.start, 1);
      expect(period?.end, 2);
    });

    test('节次范围 第5-6节 解析', () {
      final period = TimetableParser.parsePeriod('数据结构 第5-6节');
      expect(period?.start, 5);
      expect(period?.end, 6);
    });
  });

  group('TimetableParser HTML 课表格子解析测试', () {
    const parser = TimetableParser();

    test('解析典型 URP 课表格子 HTML', () {
      const sampleHtml = '''
      <html>
        <body>
          <table class="title-top-1">
            <tr>
              <td>时间</td><td>周一</td><td>周二</td><td>周三</td><td>周四</td><td>周五</td><td>周六</td><td>周日</td>
            </tr>
            <tr>
              <td>1-2节</td>
              <td>高等数学(上)<br>李教授<br>1-16周<br>七教301</td>
              <td>&nbsp;</td>
              <td>大学英语<br>王老师<br>1-8周<br>二教204</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
            </tr>
            <tr>
              <td>3-4节</td>
              <td>&nbsp;</td>
              <td>数据结构<br>张老师<br>1-16周<br>五教102</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
              <td>&nbsp;</td>
            </tr>
            <tr>
              <td>5-6节</td>
              <td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>
            </tr>
            <tr>
              <td>7-8节</td>
              <td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final courses = parser.parse(sampleHtml);
      expect(courses.length, 3);

      final math = courses.firstWhere((c) => c.name.contains('高等数学'));
      expect(math.dayOfWeek, 1);
      expect(math.startPeriod, 1);
      expect(math.endPeriod, 2);
      expect(math.classroom, '七教301');
      expect(math.teacher, '李教授');
      expect(math.weeks.length, 16);

      final ds = courses.firstWhere((c) => c.name.contains('数据结构'));
      expect(ds.dayOfWeek, 2);
      expect(ds.startPeriod, 3);
      expect(ds.endPeriod, 4);
      expect(ds.classroom, '五教102');
    });

    test('解析现代 URP Ajax 返回的 JSON 格式课表（包含 selectCourseList 与 timeAndPlaceList）', () {
      const sampleJson = '''
      {
        "dateList": [
          {
            "selectCourseList": [
              {
                "courseName": "操作系统原理",
                "attendClassTeacher": "陈老师",
                "timeAndPlaceList": [
                  {
                    "classDay": 3,
                    "classSessions": 5,
                    "continuingSession": 2,
                    "teachingBuildingName": "第九教学楼",
                    "classroomName": "402多媒体教室",
                    "classWeek": "11111111111111110000"
                  }
                ]
              },
              {
                "courseName": "软件工程",
                "attendClassTeacher": "王老师*",
                "timeAndPlaceList": [
                  {
                    "classDay": 5,
                    "classSessions": 1,
                    "continuingSession": 2,
                    "teachingBuildingName": "信息技术中心",
                    "classroomName": "机房B",
                    "classWeek": "1-8周"
                  }
                ]
              }
            ]
          }
        ]
      }
      ''';

      final courses = parser.parse(sampleJson);
      expect(courses.length, 2);

      final os = courses.firstWhere((c) => c.name == '操作系统原理');
      expect(os.teacher, '陈老师');
      expect(os.dayOfWeek, 3);
      expect(os.startPeriod, 5);
      expect(os.endPeriod, 6);
      expect(os.classroom, '第九教学楼 402多媒体教室');
      expect(os.weeks.length, 16);

      final se = courses.firstWhere((c) => c.name == '软件工程');
      expect(se.teacher, '王老师');
      expect(se.dayOfWeek, 5);
      expect(se.startPeriod, 1);
      expect(se.endPeriod, 2);
      expect(se.weeks.length, 8);
    });

    test('周次位图 parseWeekBitmap 正确映射', () {
      final weeks = TimetableParser.parseWeekBitmap('1010101000000000');
      expect(weeks, [1, 3, 5, 7]);
    });
  });
}
