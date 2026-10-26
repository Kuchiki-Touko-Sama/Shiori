import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/calculator/gpa_calculator.dart';
import 'package:shiori/data/models/grade.dart';
import 'package:shiori/features/grades/grades_controller.dart';
import 'package:shiori/shared/widgets/frosted_app_bar.dart';

/// 成绩与 GPA 统计页面。
class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gradesControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: frostedFlexibleSpace(context),
        title: const Text('成绩与 GPA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: '切换绩点算法',
            onPressed: () => _showAlgorithmDialog(context, ref, state.algorithm),
          ),
          IconButton(
            icon: Icon(
              state.showTrendChart
                  ? Icons.show_chart
                  : Icons.show_chart_outlined,
            ),
            tooltip: state.showTrendChart ? '收起趋势图' : '展开趋势图',
            onPressed: () {
              ref.read(gradesControllerProvider.notifier).toggleTrendChart();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新成绩',
            onPressed: () {
              unawaited(
                ref
                    .read(gradesControllerProvider.notifier)
                    .loadGrades(forceRefresh: true),
              );
            },
          ),
        ],
        bottom: state.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(gradesControllerProvider.notifier)
            .loadGrades(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _SummaryHeaderCard(
              summary: state.currentSummary,
              algorithm: state.algorithm,
              selectedSemester: state.selectedSemester,
              onTapAlgorithm: () =>
                  _showAlgorithmDialog(context, ref, state.algorithm),
            ),
            if (state.showTrendChart && state.trendData.length >= 2) ...[
              const SizedBox(height: 12),
              _GpaTrendChartCard(
                trendData: state.trendData,
                scheme: scheme,
              ),
            ],
            const SizedBox(height: 12),
            _SemesterFilterChips(
              availableSemesters: state.availableSemesters,
              selectedSemester: state.selectedSemester,
              onSelected: (sem) {
                ref.read(gradesControllerProvider.notifier).setSemester(sem);
              },
            ),
            const SizedBox(height: 12),
            if (state.filteredGrades.isEmpty && !state.isLoading)
              _buildEmptyView(context, scheme)
            else
              for (final grade in state.filteredGrades) ...[
                _GradeCard(grade: grade),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  void _showAlgorithmDialog(
    BuildContext context,
    WidgetRef ref,
    GpaAlgorithm current,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择 GPA 计算模式'),
          content: RadioGroup<GpaAlgorithm>(
            groupValue: current,
            onChanged: (selected) {
              if (selected != null) {
                ref
                    .read(gradesControllerProvider.notifier)
                    .setAlgorithm(selected);
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: GpaAlgorithm.values.map((algo) {
                return RadioListTile<GpaAlgorithm>(
                  title: Text(algo.label),
                  value: algo,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              '当前学期暂无成绩',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeaderCard extends StatelessWidget {
  const _SummaryHeaderCard({
    required this.summary,
    required this.algorithm,
    required this.selectedSemester,
    required this.onTapAlgorithm,
  });

  final GpaSummary summary;
  final GpaAlgorithm algorithm;
  final String? selectedSemester;
  final VoidCallback onTapAlgorithm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedSemester != null ? '$selectedSemester 成绩汇总' : '历年总体汇总',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                InkWell(
                  onTap: onTapAlgorithm,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          algorithm.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.gpa.toStringAsFixed(2),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                      ),
                      Text(
                        '平均绩点 (GPA)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 48,
                  width: 1,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary.weightedAverage} 分',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '加权均分',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 48,
                  width: 1,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary.totalCredits} 分',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '总学分 (${summary.courseCount}门)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GpaTrendChartCard extends StatelessWidget {
  const _GpaTrendChartCard({
    required this.trendData,
    required this.scheme,
  });

  final List<({String semester, double gpa, double avg})> trendData;
  final ColorScheme scheme;

  String _formatShortSemester(String sem) {
    // 匹配形如 "2023-2024学年秋季学期"
    final m =
        RegExp(r'(\d{2})(\d{2})-(\d{2})(\d{2})学年([秋春夏])').firstMatch(sem);
    if (m != null) {
      final startYear = m.group(2);
      final endYear = m.group(4);
      final term = m.group(5);
      if (term == '秋') {
        return '$startYear秋';
      } else if (term == '春') {
        return '$endYear春';
      } else {
        return '$startYear$term';
      }
    }

    // 匹配形如 "2023-2024-1"
    final m2 = RegExp(r'(\d{2})\d{2}-\d{2}(\d{2})-(\d)').firstMatch(sem);
    if (m2 != null) {
      final startYear = m2.group(1);
      final term =
          m2.group(3) == '1' ? '秋' : (m2.group(3) == '2' ? '春' : m2.group(3));
      return '$startYear$term';
    }

    return sem
        .replaceAll('学期', '')
        .replaceAll('学年', '')
        .replaceAllMapped(RegExp(r'20(\d\d)'), (match) => match.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i].gpa));
    }

    final minGpa = trendData.isEmpty
        ? 1.0
        : trendData.map((e) => e.gpa).reduce((a, b) => a < b ? a : b);
    final maxGpa = trendData.isEmpty
        ? 4.0
        : trendData.map((e) => e.gpa).reduce((a, b) => a > b ? a : b);
    final chartMinY = (minGpa - 0.6).clamp(0.0, 3.0).floorToDouble();
    final chartMaxY = (maxGpa + 0.6).clamp(2.0, 4.5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '历学期 GPA 走向趋势',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          if (idx >= 0 && idx < trendData.length) {
                            final item = trendData[idx];
                            return LineTooltipItem(
                              '${item.semester}\nGPA: ${item.gpa.toStringAsFixed(2)}  均分: ${item.avg.toStringAsFixed(1)}',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (value != idx.toDouble() ||
                              idx < 0 ||
                              idx >= trendData.length) {
                            return const SizedBox();
                          }
                          final shortName =
                              _formatShortSemester(trendData[idx].semester);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: scheme.primary,
                          strokeColor: scheme.surface,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterFilterChips extends StatelessWidget {
  const _SemesterFilterChips({
    required this.availableSemesters,
    required this.selectedSemester,
    required this.onSelected,
  });

  final List<String> availableSemesters;
  final String? selectedSemester;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部历年'),
            selected: selectedSemester == null,
            onSelected: (selected) {
              if (selected) onSelected(null);
            },
          ),
          for (final sem in availableSemesters) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(sem),
              selected: selectedSemester == sem,
              onSelected: (selected) {
                if (selected) onSelected(sem);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.grade});

  final GradeItem grade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color badgeColor;
    Color onBadgeColor;
    final scoreVal = grade.score ?? 0.0;

    if (!grade.isPassed) {
      badgeColor = scheme.errorContainer;
      onBadgeColor = scheme.onErrorContainer;
    } else if (scoreVal >= 90) {
      badgeColor = const Color(0xFFC8E6C9); // 柔和绿
      onBadgeColor = const Color(0xFF1B5E20);
    } else if (scoreVal >= 80) {
      badgeColor = const Color(0xFFBBDEFB); // 柔和蓝
      onBadgeColor = const Color(0xFF0D47A1);
    } else if (scoreVal >= 70) {
      badgeColor = const Color(0xFFFFF9C4); // 柔和黄
      onBadgeColor = const Color(0xFFF57F17);
    } else {
      badgeColor = scheme.surfaceContainerHighest;
      onBadgeColor = scheme.onSurfaceVariant;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.courseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          grade.courseType,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${grade.credit} 学分 · 绩点 ${grade.gradePoint.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  if (grade.semester.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      grade.semester,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                grade.rawScore,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onBadgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
