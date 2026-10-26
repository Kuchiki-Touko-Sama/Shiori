import 'dart:math' as math;
import 'package:shiori/data/models/grade.dart';

/// GPA 换算算法模式。
enum GpaAlgorithm {
  /// 河北大学 4.0 制：
  /// - 60 分对应 1.0；85 分对应 3.5；90 分及以上对应 4.0
  /// - 算式：score >= 60 ? min(4.0, (score - 60) / 10.0 + 1.0) : 0.0
  hbu4('河北大学 4.0 制'),

  /// 标准 4.0 制（分段阶梯）：
  /// - 90~100: 4.0
  /// - 80~89: 3.0
  /// - 70~79: 2.0
  /// - 60~69: 1.0
  /// - < 60: 0.0
  standard4('标准 4.0 阶梯制'),

  /// 北京大学 4.0 制（平滑曲线）：
  /// - 4.0 - 3 * (100 - X)^2 / 1600 (X in [60, 100])
  pku4('北大 4.0 曲线制');

  GpaAlgorithm(this.label);
  final String label;
}

/// 成绩与绩点统计汇总结果。
class GpaSummary {
  const GpaSummary({
    required this.gpa,
    required this.weightedAverage,
    required this.totalCredits,
    required this.passedCredits,
    required this.courseCount,
    required this.failedCoursesCount,
  });

  /// 平均绩点 GPA（如 3.65）
  final double gpa;

  /// 加权平均成绩（百分制，如 86.8）
  final double weightedAverage;

  /// 修读总学分
  final double totalCredits;

  /// 已通过学分
  final double passedCredits;

  /// 修读课程门数
  final int courseCount;

  /// 未及格（需补考/重修）门数
  final int failedCoursesCount;
}

/// GPA 与均分计算引擎。
class GpaCalculator {
  const GpaCalculator();

  /// 计算给定成绩列表的 GPA 与学分汇总
  static GpaSummary calculate({
    required List<GradeItem> grades,
    GpaAlgorithm algorithm = GpaAlgorithm.hbu4,
  }) {
    if (grades.isEmpty) {
      return const GpaSummary(
        gpa: 0,
        weightedAverage: 0,
        totalCredits: 0,
        passedCredits: 0,
        courseCount: 0,
        failedCoursesCount: 0,
      );
    }

    var totalCredits = 0.0;
    var passedCredits = 0.0;
    var totalWeightedPoints = 0.0;
    var totalWeightedScore = 0.0;
    var scoredCredits = 0.0;
    var failedCount = 0;

    for (final item in grades) {
      final credit = item.credit;
      totalCredits += credit;

      final numericScore = item.score ?? parseScore(item.rawScore);

      if (item.isPassed) {
        passedCredits += credit;
      } else {
        failedCount++;
      }

      final point = calculatePoint(numericScore, algorithm);
      totalWeightedPoints += point * credit;

      totalWeightedScore += numericScore * credit;
      scoredCredits += credit;
    }

    final gpa =
        totalCredits > 0 ? (totalWeightedPoints / totalCredits) : 0.0;
    final weightedAverage =
        scoredCredits > 0 ? (totalWeightedScore / scoredCredits) : 0.0;

    return GpaSummary(
      gpa: double.parse(gpa.toStringAsFixed(2)),
      weightedAverage: double.parse(weightedAverage.toStringAsFixed(1)),
      totalCredits: totalCredits,
      passedCredits: passedCredits,
      courseCount: grades.length,
      failedCoursesCount: failedCount,
    );
  }

  /// 将文字等第或字符串成绩转换为百分制数值
  static double parseScore(String raw) {
    final trimmed = raw.trim();
    final directVal = double.tryParse(trimmed);
    if (directVal != null) return directVal;

    // 常见等第成绩换算（先判定「不及格」以防命中「及格」）
    if (trimmed.contains('不及格') ||
        trimmed.contains('不合格') ||
        trimmed.contains('F')) {
      return 50;
    }
    if (trimmed.contains('优') || trimmed.contains('A')) return 95;
    if (trimmed.contains('良') || trimmed.contains('B')) return 85;
    if (trimmed.contains('中') || trimmed.contains('C')) return 75;
    if (trimmed.contains('及格') || trimmed.contains('D')) return 65;
    if (trimmed.contains('合格') || trimmed.contains('通过')) return 80;

    return 60;
  }

  /// 计算单门课程的绩点
  static double calculatePoint(double score, GpaAlgorithm algorithm) {
    if (score < 60) return 0;

    switch (algorithm) {
      case GpaAlgorithm.hbu4:
        // 河大 4.0：60 分对应 1.0，90 分及以上满绩 4.0
        final point = (score - 60) / 10 + 1;
        return math.min(4, math.max(0, point));

      case GpaAlgorithm.standard4:
        if (score >= 90) return 4;
        if (score >= 80) return 3;
        if (score >= 70) return 2;
        return 1;

      case GpaAlgorithm.pku4:
        final delta = 100 - score;
        final point = 4 - 3 * (delta * delta) / 1600;
        return math.min(4, math.max(0, point));
    }
  }
}
