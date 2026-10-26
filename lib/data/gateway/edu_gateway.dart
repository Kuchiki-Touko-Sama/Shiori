import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/models/course.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/models/exam.dart';
import 'package:shiori/data/models/grade.dart';

/// 教务系统统一网关抽象接口。
///
/// 为河北大学及未来扩展其他高校教务系统提供统一业务契约。
abstract interface class EduSystemGateway {
  /// 获取指定学期（默认当前学期）的课程表
  Future<List<Course>> getTimetable({String? semester});

  /// 获取指定学期的考试安排
  Future<List<ExamItem>> getExams({String? semester});

  /// 获取指定学期或全部历年成绩
  Future<List<GradeItem>> getGrades({String? semester});

  /// 获取可选学期列表（例如 ['2026-2027-1', '2025-2026-2']）
  Future<List<String>> getAvailableSemesters();

  /// 获取学生评教列表
  Future<List<EvaluationItem>> getEvaluations();

  /// 提交单项评教问卷
  Future<bool> submitEvaluation(
    EvaluationItem item, {
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
  });
}

/// 全局教务网关 Provider（由具体实现覆盖或提供）
final eduGatewayProvider = Provider<EduSystemGateway>((ref) {
  throw UnimplementedError('eduGatewayProvider 需注入具体实现');
});
