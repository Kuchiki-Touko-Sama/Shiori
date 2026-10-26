import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/course.dart';

/// 课表页面状态。
class TimetableState {
  const TimetableState({
    this.courses = const <Course>[],
    this.currentWeek = 1,
    this.selectedSemester = '2026-2027学年秋季学期',
    this.availableSemesters = const <String>[],
    this.isLoading = false,
    this.errorMessage,
  });

  /// 所有的课程列表
  final List<Course> courses;

  /// 当前选中的查看周次（1..20）
  final int currentWeek;

  /// 当前选中的学期
  final String selectedSemester;

  /// 可选学期列表
  final List<String> availableSemesters;

  /// 是否正在加载中
  final bool isLoading;

  /// 错误提示
  final String? errorMessage;

  /// 当前选中周次活跃（需要上课）的课程
  List<Course> get activeCourses =>
      courses.where((c) => c.isActiveInWeek(currentWeek)).toList();

  TimetableState copyWith({
    List<Course>? courses,
    int? currentWeek,
    String? selectedSemester,
    List<String>? availableSemesters,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TimetableState(
      courses: courses ?? this.courses,
      currentWeek: currentWeek ?? this.currentWeek,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      availableSemesters: availableSemesters ?? this.availableSemesters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 课表控制器。
class TimetableController extends Notifier<TimetableState> {
  @override
  TimetableState build() {
    unawaited(Future.microtask(loadTimetable));
    return const TimetableState();
  }

  /// 加载课表数据
  Future<void> loadTimetable({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);

    try {
      final gateway = ref.read(hbuUrpGatewayProvider);
      final semesters = await gateway.getAvailableSemesters();
      final courses = await gateway.getTimetable(
        semester: state.selectedSemester,
      );

      state = state.copyWith(
        courses: courses,
        availableSemesters: semesters,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载课表失败: $e',
      );
    }
  }

  /// 切换当前查看周次
  void setCurrentWeek(int week) {
    if (week >= 1 && week <= 25) {
      state = state.copyWith(currentWeek: week);
    }
  }

  /// 切换学期
  Future<void> setSemester(String semester) async {
    state = state.copyWith(selectedSemester: semester);
    await loadTimetable(forceRefresh: true);
  }
}

/// 课表控制器 Provider。
final timetableControllerProvider =
    NotifierProvider<TimetableController, TimetableState>(
  TimetableController.new,
);
