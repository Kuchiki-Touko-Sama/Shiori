import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/exam.dart';

/// 考试安排页面状态。
class ExamState {
  const ExamState({
    this.exams = const <ExamItem>[],
    this.isLoading = false,
    this.errorMessage,
  });

  /// 考试列表
  final List<ExamItem> exams;

  /// 加载状态
  final bool isLoading;

  /// 错误提示
  final String? errorMessage;

  /// 未完成（待考）的考试
  List<ExamItem> get upcomingExams =>
      exams.where((e) => !e.isFinished).toList();

  /// 已考完的考试
  List<ExamItem> get finishedExams =>
      exams.where((e) => e.isFinished).toList();

  ExamState copyWith({
    List<ExamItem>? exams,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ExamState(
      exams: exams ?? this.exams,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 考试安排控制器。
class ExamController extends Notifier<ExamState> {
  @override
  ExamState build() {
    unawaited(Future.microtask(loadExams));
    return const ExamState();
  }

  /// 加载考试数据
  Future<void> loadExams({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);

    try {
      final gateway = ref.read(hbuUrpGatewayProvider);
      final exams = await gateway.getExams();

      state = state.copyWith(
        exams: exams,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载考试安排失败: $e',
      );
    }
  }
}

/// 考试控制器 Provider。
final examControllerProvider =
    NotifierProvider<ExamController, ExamState>(
  ExamController.new,
);
