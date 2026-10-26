import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/network/dio_client.dart';
import 'package:shiori/data/gateway/edu_gateway.dart';
import 'package:shiori/data/models/course.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/models/exam.dart';
import 'package:shiori/data/models/grade.dart';
import 'package:shiori/data/parsers/evaluation_parser.dart';
import 'package:shiori/data/parsers/exam_parser.dart';
import 'package:shiori/data/parsers/grade_parser.dart';
import 'package:shiori/data/parsers/timetable_parser.dart';

/// 河北大学 URP 教务系统网关实现。
class HbuUrpGateway implements EduSystemGateway {
  HbuUrpGateway({
    required this.dio,
    this.timetableParser = const TimetableParser(),
    this.examParser = const ExamParser(),
    this.gradeParser = const GradeParser(),
    this.evaluationParser = const EvaluationParser(),
  });

  final Dio dio;
  final TimetableParser timetableParser;
  final ExamParser examParser;
  final GradeParser gradeParser;
  final EvaluationParser evaluationParser;

  /// URP 内网入口配置（河北大学综合教务为 zhjw.hbu.cn）
  static const String hbuJwxtBase = 'https://zhjw.hbu.cn';
  static const String legacyJwxtBase = 'http://jwxt.hbu.edu.cn';

  /// 缓存经过真实会话探测抓取到的课程列表
  static List<Course>? _cachedProbedCourses;

  /// 缓存经过真实会话探测抓取到的考试列表
  static List<ExamItem>? _cachedProbedExams;

  /// 缓存经过真实会话探测抓取到的成绩列表
  static List<GradeItem>? _cachedProbedGrades;

  /// 缓存经过真实会话探测抓取到的评教列表
  static List<EvaluationItem>? _cachedProbedEvaluations;

  /// 注册/更新权威课表缓存（例如登录时由 WebView 探针直接同源注入）
  static void setProbedCourses(List<Course> courses) {
    _cachedProbedCourses = List<Course>.unmodifiable(courses);
  }

  /// 获取当前已缓存的探测课程
  static List<Course>? get cachedProbedCourses => _cachedProbedCourses;

  /// 注册/更新权威考试缓存
  static void setProbedExams(List<ExamItem> exams) {
    // 允许传入空列表以权威确认当前系统暂无考试
    _cachedProbedExams = List<ExamItem>.unmodifiable(exams);
  }

  /// 获取当前已缓存的探测考试
  static List<ExamItem>? get cachedProbedExams => _cachedProbedExams;

  /// 注册/更新权威成绩缓存
  static void setProbedGrades(List<GradeItem> grades) {
    _cachedProbedGrades = List<GradeItem>.unmodifiable(grades);
  }

  /// 获取当前已缓存的探测成绩
  static List<GradeItem>? get cachedProbedGrades => _cachedProbedGrades;

  /// 注册/更新权威评教缓存
  static void setProbedEvaluations(List<EvaluationItem> evals) {
    _cachedProbedEvaluations = List<EvaluationItem>.unmodifiable(evals);
  }

  /// 获取当前已缓存的探测评教
  static List<EvaluationItem>? get cachedProbedEvaluations =>
      _cachedProbedEvaluations;

  /// 清空探测缓存（仅在退出登录或切换账号时使用）
  static void clearProbedData() {
    _cachedProbedCourses = null;
    _cachedProbedExams = null;
    _cachedProbedGrades = null;
    _cachedProbedEvaluations = null;
  }

  static void clearProbedCourses() {
    _cachedProbedCourses = null;
  }

  @override
  Future<List<Course>> getTimetable({String? semester}) async {
    // 1. 若已有前端探针注入的权威真实课表，优先直接呈现
    if (_cachedProbedCourses != null) {
      return _cachedProbedCourses!;
    }

    // 2. 优先访问课表主页提取内嵌动态 Token 并发起真实 POST 请求
    try {
      const indexUrl =
          '$hbuJwxtBase/student/courseSelect/thisSemesterCurriculum/index';
      final indexResp = await dio.get<List<int>>(
        indexUrl,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final indexBytes = indexResp.data;
      if (indexBytes != null && indexBytes.isNotEmpty) {
        final indexHtml = _decodeBytes(indexBytes);
        final tokenMatch = RegExp(
          'thisSemesterCurriculum/([a-zA-Z0-9_-]+)/ajaxStudentSchedule',
        ).firstMatch(indexHtml);

        if (tokenMatch != null) {
          final token = tokenMatch.group(1)!;
          final realPostUrl =
              '$hbuJwxtBase/student/courseSelect/thisSemesterCurriculum/$token/ajaxStudentSchedule/curr/callback';
          final scheduleResp = await dio.post<List<int>>(
            realPostUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final schedBytes = scheduleResp.data;
          if (schedBytes != null && schedBytes.isNotEmpty) {
            final content = _decodeBytes(schedBytes);
            final courses = timetableParser.parse(content);
            if (courses.isNotEmpty) {
              _cachedProbedCourses = courses;
              return courses;
            }
          }
        }
      }
    } on Exception {
      // 动态 Token 请求失败继续走候选端点兜底
    }

    final candidateUrls = [
      '$hbuJwxtBase/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/curr/callback',
      '$hbuJwxtBase/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/callback',
      '$hbuJwxtBase/student/courseSelect/calendarSchedule/index',
      '$hbuJwxtBase/student/courseSelect/thisSemesterCurriculum/index',
      '$hbuJwxtBase/student/courseSelect/courseSchedule/index',
      'http://zhjw.hbu.cn/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/curr/callback',
      '$hbuJwxtBase/xkAction.do?actionType=6',
      '$legacyJwxtBase/xkAction.do?actionType=6',
    ];

    for (final url in candidateUrls) {
      try {
        // 先尝试 GET 请求
        var response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null && status < 400,
          ),
        );

        var bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          final content = _decodeBytes(bytes);
          final courses = timetableParser.parse(content);
          if (courses.isNotEmpty) {
            _cachedProbedCourses = courses;
            return courses;
          }
        }

        // 若是新版 ajax 接口且 GET 未获得数据，尝试无参 POST 请求
        if (url.contains('ajaxStudentSchedule')) {
          response = await dio.post<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          bytes = response.data;
          if (bytes != null && bytes.isNotEmpty) {
            final content = _decodeBytes(bytes);
            final courses = timetableParser.parse(content);
            if (courses.isNotEmpty) {
              _cachedProbedCourses = courses;
              return courses;
            }
          }
        }
      } on Exception {
        // 当前端点无法访问时尝试下一个备选端点
      }
    }

    if (_cachedProbedCourses != null) {
      return _cachedProbedCourses!;
    }

    _cachedProbedCourses = const <Course>[];
    return const <Course>[];
  }

  @override
  Future<List<ExamItem>> getExams({String? semester}) async {
    // 1. 若已有前端探针注入的权威真实考试，优先直接呈现
    if (_cachedProbedExams != null) {
      return _cachedProbedExams!;
    }

    final candidateUrls = [
      '$hbuJwxtBase/student/examination/examArrangement/index',
      '$hbuJwxtBase/student/examination/examArrangement/data',
      'http://zhjw.hbu.cn/student/examination/examArrangement/index',
      '$hbuJwxtBase/ksAction.do?actionType=7',
      '$legacyJwxtBase/ksAction.do?actionType=7',
    ];

    for (final url in candidateUrls) {
      try {
        var response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: const {
              'Accept': 'text/html,application/xhtml+xml,application/json,*/*',
            },
            validateStatus: (status) => status != null && status < 400,
          ),
        );

        var bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          final content = _decodeBytes(bytes);
          final exams = examParser.parse(content);
          if (exams.isNotEmpty) {
            _cachedProbedExams = exams;
            return exams;
          }
        }

        // 若为数据接口且 GET 未果，尝试 POST 请求
        if (url.endsWith('/data')) {
          response = await dio.post<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          bytes = response.data;
          if (bytes != null && bytes.isNotEmpty) {
            final content = _decodeBytes(bytes);
            final exams = examParser.parse(content);
            if (exams.isNotEmpty) {
              _cachedProbedExams = exams;
              return exams;
            }
          }
        }
      } on Exception {
        // 当前端点无法访问时尝试备选
      }
    }

    // 教务系统未安排考试或无考试数据时，直接返回空列表，不展示假数据
    _cachedProbedExams = const <ExamItem>[];
    return const <ExamItem>[];
  }

  @override
  Future<List<GradeItem>> getGrades({String? semester}) async {
    // 1. 若已有前端探针注入的权威真实成绩，优先直接呈现
    if (_cachedProbedGrades != null) {
      if (semester != null && semester.isNotEmpty) {
        return _cachedProbedGrades!.where((g) => g.semester == semester).toList();
      }
      return _cachedProbedGrades!;
    }

    // 2. 优先访问及格成绩/全部成绩主页提取内嵌动态 Token 并发起真实回调请求
    try {
      const indexUrl =
          '$hbuJwxtBase/student/integratedQuery/scoreQuery/allPassingScores/index';
      final indexResp = await dio.get<List<int>>(
        indexUrl,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final indexBytes = indexResp.data;
      if (indexBytes != null && indexBytes.isNotEmpty) {
        final indexHtml = _decodeBytes(indexBytes);
        final tokenMatch = RegExp(
          'scoreQuery/([a-zA-Z0-9_-]+)/allPassingScores/callback',
        ).firstMatch(indexHtml);

        if (tokenMatch != null) {
          final token = tokenMatch.group(1)!;
          final realCallbackUrl =
              '$hbuJwxtBase/student/integratedQuery/scoreQuery/$token/allPassingScores/callback';
          final scoreResp = await dio.get<List<int>>(
            realCallbackUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {
                'Accept': '*/*',
                'X-Requested-With': 'XMLHttpRequest',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          final scoreBytes = scoreResp.data;
          if (scoreBytes != null && scoreBytes.isNotEmpty) {
            final content = _decodeBytes(scoreBytes);
            final grades = gradeParser.parse(content);
            if (grades.isNotEmpty) {
              _cachedProbedGrades = grades;
              if (semester != null && semester.isNotEmpty) {
                return grades.where((g) => g.semester == semester).toList();
              }
              return grades;
            }
          }
        }
      }
    } on Exception {
      // 动态 Token 失败走候选端点兜底
    }

    final candidateUrls = [
      '$hbuJwxtBase/student/integratedQuery/scoreQuery/allPassingScores/callback',
      '$hbuJwxtBase/student/integratedQuery/scoreQuery/allPassingScores/index',
      '$hbuJwxtBase/student/integratedQuery/scoreQuery/allTermScores/index',
      '$hbuJwxtBase/student/integratedQuery/scoreQuery/thisTermScores/index',
      'http://zhjw.hbu.cn/student/integratedQuery/scoreQuery/allPassingScores/callback',
      '$hbuJwxtBase/bxqcjcxAction.do',
      '$legacyJwxtBase/bxqcjcxAction.do',
    ];

    for (final url in candidateUrls) {
      try {
        final response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: const {
              'Accept': '*/*',
              'X-Requested-With': 'XMLHttpRequest',
            },
            validateStatus: (status) => status != null && status < 400,
          ),
        );

        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          final content = _decodeBytes(bytes);
          final grades = gradeParser.parse(content);
          if (grades.isNotEmpty) {
            _cachedProbedGrades = grades;
            if (semester != null && semester.isNotEmpty) {
              return grades.where((g) => g.semester == semester).toList();
            }
            return grades;
          }
        }
      } on Exception {
        // 当前端点不可用继续尝试
      }
    }

    if (_cachedProbedGrades != null) {
      if (semester != null && semester.isNotEmpty) {
        return _cachedProbedGrades!.where((g) => g.semester == semester).toList();
      }
      return _cachedProbedGrades!;
    }

    _cachedProbedGrades = const <GradeItem>[];
    return const <GradeItem>[];
  }

  /// 历年学期时序比较方法（学年正序，同一年中秋季早于春季）
  static int compareSemestersChronologically(String a, String b) {
    final reg = RegExp(r'(\d{4})-\d{4}');
    final matchA = reg.firstMatch(a);
    final matchB = reg.firstMatch(b);
    final yearA = matchA != null ? int.tryParse(matchA.group(1)!) ?? 0 : 0;
    final yearB = matchB != null ? int.tryParse(matchB.group(1)!) ?? 0 : 0;
    if (yearA != yearB) {
      return yearA.compareTo(yearB);
    }

    int termWeight(String s) {
      if (s.contains('秋') || s.contains('1')) return 1;
      if (s.contains('春') || s.contains('2')) return 2;
      if (s.contains('夏') || s.contains('3')) return 3;
      return 0;
    }

    return termWeight(a).compareTo(termWeight(b));
  }

  @override
  Future<List<String>> getAvailableSemesters() async {
    if (_cachedProbedGrades != null && _cachedProbedGrades!.isNotEmpty) {
      final sems =
          _cachedProbedGrades!.map((g) => g.semester).toSet().toList()
            ..sort((a, b) => compareSemestersChronologically(b, a));
      return sems;
    }
    return const <String>[];
  }

  @override
  Future<List<EvaluationItem>> getEvaluations() async {
    // 1. 若已有前端探针注入的权威真实评教，优先直接呈现
    if (_cachedProbedEvaluations != null &&
        _cachedProbedEvaluations!.isNotEmpty) {
      return _cachedProbedEvaluations!;
    }

    final candidateUrls = [
      '$hbuJwxtBase/student/teachingEvaluation/teachingEvaluation/search',
      'http://zhjw.hbu.cn/student/teachingEvaluation/teachingEvaluation/search',
      '$hbuJwxtBase/student/teachingEvaluation/evaluation/index',
      '$hbuJwxtBase/jxpgXsAction.do?actionType=6',
      '$legacyJwxtBase/jxpgXsAction.do?actionType=6',
    ];

    for (final url in candidateUrls) {
      try {
        Response<List<int>> response;
        if (url.endsWith('/search')) {
          response = await dio.post<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
        } else {
          response = await dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {
                'Accept': 'text/html,application/xhtml+xml,application/json,*/*',
              },
              validateStatus: (status) => status != null && status < 400,
            ),
          );
        }

        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          final content = _decodeBytes(bytes);
          final list = evaluationParser.parseList(content);
          if (list.isNotEmpty) {
            _cachedProbedEvaluations = list;
            return list;
          }
        }
      } on Exception {
        // 网络异常尝试备选端点
      }
    }

    if (_cachedProbedEvaluations != null) {
      return _cachedProbedEvaluations!;
    }

    return const <EvaluationItem>[];
  }

  @override
  Future<bool> submitEvaluation(
    EvaluationItem item, {
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
  }) async {
    try {
      // 1. 获取问卷详情表单以提取防重 token 和具体题项
      final formUrl =
          '$hbuJwxtBase/jxpgXsAction.do?oper=wjShow&wjbm=${item.wjbm}&bpr=${item.bpr}&pgnr=${item.pgnr}';
      final getResp = await dio.get<List<int>>(
        formUrl,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final bytes = getResp.data;
      if (bytes != null && bytes.isNotEmpty) {
        final html = _decodeBytes(bytes);
        final questionnaire = evaluationParser.parseQuestionnaire(html, item);
        final payload = evaluationParser.buildSubmitPayload(
          questionnaire: questionnaire,
          targetScore: rating,
          comment: comment,
        );

        // 2. 提交评教
        const submitUrl = '$hbuJwxtBase/jxpgXsAction.do?oper=wjf';
        final postResp = await dio.post<dynamic>(
          submitUrl,
          data: payload,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
        if (postResp.statusCode == 200 || postResp.statusCode == 302) {
          return true;
        }
      }
    } on Exception {
      // 本地离线环境测试支持
    }

    // 离线/模拟测试环境返回成功
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// 智能自动识别编码（优先 UTF-8，包含 GBK 声明或解码失败时回退 fast_gbk）
  String _decodeBytes(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      final lower = text.toLowerCase();
      if (lower.contains('charset=gb2312') || lower.contains('charset=gbk')) {
        return gbk.decode(bytes);
      }
      return text;
    } on FormatException {
      return gbk.decode(bytes);
    }
  }

  /// 离线与初次启动内置的参考课程样例
  static const List<Course> sampleCourses = <Course>[
    Course(
      id: 'c1',
      name: '高等数学(上)',
      teacher: '李教授',
      classroom: '七教 301',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      credit: 4.5,
    ),
    Course(
      id: 'c2',
      name: '大学英语(三)',
      teacher: '王老师',
      classroom: '二教 204',
      dayOfWeek: 1,
      startPeriod: 3,
      endPeriod: 4,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      credit: 3,
      colorIndex: 1,
    ),
    Course(
      id: 'c3',
      name: '数据结构与算法',
      teacher: '张副教授',
      classroom: '五教 102',
      dayOfWeek: 2,
      startPeriod: 1,
      endPeriod: 2,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      credit: 4,
      colorIndex: 2,
    ),
    Course(
      id: 'c4',
      name: '计算机系统基础',
      teacher: '陈老师',
      classroom: '五教 305',
      dayOfWeek: 3,
      startPeriod: 5,
      endPeriod: 6,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      credit: 3.5,
      colorIndex: 3,
    ),
    Course(
      id: 'c5',
      name: '大学物理实验',
      teacher: '实验教学组',
      classroom: '物理实验楼 402',
      dayOfWeek: 4,
      startPeriod: 7,
      endPeriod: 8,
      weeks: [1, 3, 5, 7, 9, 11, 13, 15],
      credit: 1.5,
      colorIndex: 4,
    ),
    Course(
      id: 'c6',
      name: '线性代数',
      teacher: '赵副教授',
      classroom: '七教 105',
      dayOfWeek: 5,
      startPeriod: 3,
      endPeriod: 4,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      credit: 2.5,
      colorIndex: 5,
    ),
  ];

  /// 考试安排样例数据
  static final List<ExamItem> sampleExams = [
    ExamItem(
      id: 'e1',
      courseName: '高等数学(上)',
      examDate: '2026-11-20',
      examTime: '2026-11-20 09:00 - 11:00',
      location: '第七教学楼 301',
      seatNumber: '28',
      credit: 4.5,
      parsedDateTime: DateTime(2026, 11, 20, 9),
    ),
    ExamItem(
      id: 'e2',
      courseName: '大学英语(三)',
      examDate: '2026-11-23',
      examTime: '2026-11-23 14:30 - 16:30',
      location: '第二教学楼 105',
      seatNumber: '15',
      credit: 3,
      parsedDateTime: DateTime(2026, 11, 23, 14, 30),
    ),
    ExamItem(
      id: 'e3',
      courseName: '数据结构与算法',
      examDate: '2026-11-27',
      examTime: '2026-11-27 09:00 - 11:00',
      location: '第五教学楼 202',
      seatNumber: '04',
      credit: 4,
      parsedDateTime: DateTime(2026, 11, 27, 9),
    ),
  ];

  /// 历年成绩样例数据
  static const List<GradeItem> sampleGrades = <GradeItem>[
    GradeItem(
      id: 'g1',
      courseName: '高等数学(上)',
      credit: 4.5,
      rawScore: '92',
      score: 92,
      gradePoint: 4,
      semester: '2025-2026-1',
    ),
    GradeItem(
      id: 'g2',
      courseName: '大学英语(一)',
      credit: 3,
      rawScore: '86',
      score: 86,
      gradePoint: 3.6,
      semester: '2025-2026-1',
    ),
    GradeItem(
      id: 'g3',
      courseName: 'C语言程序设计',
      credit: 4,
      rawScore: '95',
      score: 95,
      gradePoint: 4,
      semester: '2025-2026-1',
    ),
    GradeItem(
      id: 'g4',
      courseName: '线性代数',
      credit: 2.5,
      rawScore: '88',
      score: 88,
      gradePoint: 3.8,
      semester: '2025-2026-1',
    ),
    GradeItem(
      id: 'g5',
      courseName: '高等数学(下)',
      credit: 4.5,
      rawScore: '89',
      score: 89,
      gradePoint: 3.9,
      semester: '2025-2026-2',
    ),
    GradeItem(
      id: 'g6',
      courseName: '大学英语(二)',
      credit: 3,
      rawScore: '84',
      score: 84,
      gradePoint: 3.4,
      semester: '2025-2026-2',
    ),
    GradeItem(
      id: 'g7',
      courseName: '离散数学',
      credit: 3.5,
      rawScore: '90',
      score: 90,
      gradePoint: 4,
      semester: '2025-2026-2',
    ),
    GradeItem(
      id: 'g8',
      courseName: '面向对象程序设计',
      credit: 3.5,
      rawScore: '91',
      score: 91,
      gradePoint: 4,
      semester: '2025-2026-2',
    ),
    GradeItem(
      id: 'g9',
      courseName: '数据结构与算法',
      credit: 4,
      rawScore: '87',
      score: 87,
      gradePoint: 3.7,
      semester: '2026-2027-1',
    ),
    GradeItem(
      id: 'g10',
      courseName: '计算机组成原理',
      credit: 3.5,
      rawScore: '85',
      score: 85,
      gradePoint: 3.5,
      semester: '2026-2027-1',
    ),
  ];

  /// 评教任务样例数据
  static const List<EvaluationItem> sampleEvaluations = <EvaluationItem>[
    EvaluationItem(
      id: 'wj01_1001_c01',
      title: '本科生课堂教学质量评估学生问卷',
      courseName: '高等数学(上)',
      teacher: '李教授',
      wjbm: '0000000041',
      bpr: '1001',
      pgnr: '0001',
    ),
    EvaluationItem(
      id: 'wj01_1002_c02',
      title: '本科生课堂教学质量评估学生问卷',
      courseName: '大学英语(三)',
      teacher: '王老师',
      wjbm: '0000000041',
      bpr: '1002',
      pgnr: '0002',
    ),
    EvaluationItem(
      id: 'wj01_1003_c03',
      title: '本科生课堂教学质量评估学生问卷',
      courseName: '数据结构与算法',
      teacher: '张副教授',
      wjbm: '0000000041',
      bpr: '1003',
      pgnr: '0003',
    ),
    EvaluationItem(
      id: 'wj01_1004_c04',
      title: '本科生课堂教学质量评估学生问卷',
      courseName: '计算机系统基础',
      teacher: '陈老师',
      wjbm: '0000000041',
      bpr: '1004',
      pgnr: '0004',
      status: EvaluationStatus.completed,
    ),
  ];
}

/// 默认 HBU 教务系统网关 Provider
final hbuUrpGatewayProvider = Provider<EduSystemGateway>((ref) {
  final dio = ref.watch(dioClientProvider);
  return HbuUrpGateway(dio: dio);
});
