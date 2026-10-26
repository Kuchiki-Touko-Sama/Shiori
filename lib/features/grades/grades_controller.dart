import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/calculator/gpa_calculator.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/grade.dart';

/// 成绩页面状态。
class GradesState {
  const GradesState({
    this.allGrades = const <GradeItem>[],
    this.selectedSemester,
    this.algorithm = GpaAlgorithm.hbu4,
    this.isLoading = false,
    this.showTrendChart = true,
    this.errorMessage,
  });

  /// 历年所有成绩
  final List<GradeItem> allGrades;

  /// 当前选中的学期筛选（null 代表「全部历年」）
  final String? selectedSemester;

  /// 当前 GPA 换算算法
  final GpaAlgorithm algorithm;

  /// 加载状态
  final bool isLoading;

  /// 是否展开 GPA 趋势折线图
  final bool showTrendChart;

  /// 错误提示
  final String? errorMessage;

  /// 历年各学期排序算法（学年正序，同一年中秋季第1学期在春季第2学期之前）
  static int compareSemestersChronologically(String a, String b) =>
      HbuUrpGateway.compareSemestersChronologically(a, b);

  /// 从成绩中提取的所有可用学期列表（最新学期排在最前，降序）
  List<String> get availableSemesters {
    final sems = allGrades
        .map((g) => g.semester)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => compareSemestersChronologically(b, a));
    return sems;
  }

  /// 当前选中学期（或历年全部）过滤后的成绩列表
  List<GradeItem> get filteredGrades {
    if (selectedSemester == null) return allGrades;
    return allGrades.where((g) => g.semester == selectedSemester).toList();
  }

  /// 当前筛选范围的 GPA 与学分汇总
  GpaSummary get currentSummary => GpaCalculator.calculate(
        grades: filteredGrades,
        algorithm: algorithm,
      );

  /// 历年各学期 GPA 走向趋势（用于折线图，按学期时间正序）
  List<({String semester, double gpa, double avg})> get trendData {
    final sems = allGrades
        .map((g) => g.semester)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort(compareSemestersChronologically); // 正序

    return sems.map((sem) {
      final sGrades = allGrades.where((g) => g.semester == sem).toList();
      final summary = GpaCalculator.calculate(
        grades: sGrades,
        algorithm: algorithm,
      );
      return (
        semester: sem,
        gpa: summary.gpa,
        avg: summary.weightedAverage,
      );
    }).toList();
  }

  GradesState copyWith({
    List<GradeItem>? allGrades,
    String? selectedSemester,
    bool clearSemester = false,
    GpaAlgorithm? algorithm,
    bool? isLoading,
    bool? showTrendChart,
    String? errorMessage,
  }) {
    return GradesState(
      allGrades: allGrades ?? this.allGrades,
      selectedSemester:
          clearSemester ? null : (selectedSemester ?? this.selectedSemester),
      algorithm: algorithm ?? this.algorithm,
      isLoading: isLoading ?? this.isLoading,
      showTrendChart: showTrendChart ?? this.showTrendChart,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 成绩状态控制器。
class GradesController extends Notifier<GradesState> {
  @override
  GradesState build() {
    unawaited(Future.microtask(loadGrades));
    return const GradesState();
  }

  /// 加载历年成绩
  Future<void> loadGrades({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);

    try {
      final gateway = ref.read(hbuUrpGatewayProvider);
      final grades = await gateway.getGrades();

      state = state.copyWith(
        allGrades: grades,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载成绩失败: $e',
      );
    }
  }

  /// 切换学期筛选（传 null 恢复全部）
  void setSemester(String? semester) {
    if (semester == null) {
      state = state.copyWith(clearSemester: true);
    } else {
      state = state.copyWith(selectedSemester: semester);
    }
  }

  /// 切换 GPA 换算算法
  void setAlgorithm(GpaAlgorithm algo) {
    state = state.copyWith(algorithm: algo);
  }

  /// 展开 / 收起趋势图
  void toggleTrendChart() {
    state = state.copyWith(showTrendChart: !state.showTrendChart);
  }
}

/// 成绩控制器 Provider。
final gradesControllerProvider =
    NotifierProvider<GradesController, GradesState>(
  GradesController.new,
);
