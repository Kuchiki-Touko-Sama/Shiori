import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/calendar/ics_exporter.dart';
import 'package:shiori/data/models/course.dart';
import 'package:shiori/features/timetable/timetable_controller.dart';

/// 周课表页面。
class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timetableControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showWeekPicker(context, ref, state.currentWeek),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '第 ${state.currentWeek} 周',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: '回到第 1 周',
            onPressed: () {
              ref
                  .read(timetableControllerProvider.notifier)
                  .setCurrentWeek(1);
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '导出为 .ics 日历',
            onPressed: () => _showExportIcsDialog(context, state.courses),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新课表',
            onPressed: () {
              unawaited(
                ref
                    .read(timetableControllerProvider.notifier)
                    .loadTimetable(forceRefresh: true),
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
      body: Column(
        children: [
          _WeekHeader(currentDayOfWeek: DateTime.now().weekday),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(timetableControllerProvider.notifier)
                  .loadTimetable(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _TimetableGrid(
                  courses: state.activeCourses,
                  currentWeek: state.currentWeek,
                  scheme: scheme,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeekPicker(
    BuildContext context,
    WidgetRef ref,
    int currentWeek,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择查看周次',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(20, (index) {
                    final week = index + 1;
                    final isSelected = week == currentWeek;
                    return ChoiceChip(
                      label: Text('第$week周'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(timetableControllerProvider.notifier)
                              .setCurrentWeek(week);
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExportIcsDialog(BuildContext context, List<Course> courses) {
    // 假设本学期第一周周一为 2026 年 9 月 1 日
    final semesterStart = DateTime(2026, 9);
    const exporter = IcsExporter();
    final icsContent = exporter.export(
      courses: courses,
      semesterStartDate: semesterStart,
    );

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('导出系统日历 (.ics)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '已生成符合 RFC 5545 标准的日历事件文件，支持导入系统日历（Google Calendar、苹果日历、小米日历等）。',
            ),
            const SizedBox(height: 12),
            Text(
              '共包含 ${courses.length} 门课程的定时节次与提前 20 分钟闹钟提醒。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '第一周周一：2026-09-01\n总计事件字符：${icsContent.length} 字节',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已准备好 .ics 日历数据')),
              );
            },
            icon: const Icon(Icons.download_done),
            label: const Text('完成导出'),
          ),
        ],
      ),
    ));
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.currentDayOfWeek});

  final int currentDayOfWeek;
  static const List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 左侧节次空白占位
          const SizedBox(width: 36),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '周${_weekDays[i]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i + 1 == currentDayOfWeek
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i + 1 == currentDayOfWeek
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (i + 1 == currentDayOfWeek)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.courses,
    required this.currentWeek,
    required this.scheme,
  });

  final List<Course> courses;
  final int currentWeek;
  final ColorScheme scheme;

  static const double _rowHeight = 60;
  static const int _totalPeriods = 12;

  // 课程卡片颜色库（优雅柔和的 M3 色板）
  static const List<Color> _palette = [
    Color(0xFF81C784), // 浅绿
    Color(0xFF64B5F6), // 浅蓝
    Color(0xFFFFB74D), // 橙黄
    Color(0xFFBA68C8), // 浅紫
    Color(0xFF4DB6AC), // 青绿
    Color(0xFFE57373), // 浅红
    Color(0xFF4DD0E1), // 湖蓝
    Color(0xFFAED581), // 黄绿
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - 36) / 7;

        return SizedBox(
          height: _totalPeriods * _rowHeight,
          child: Stack(
            children: [
              // 节次时间轴背景线与数字
              for (var i = 1; i <= _totalPeriods; i++) ...[
                Positioned(
                  top: (i - 1) * _rowHeight,
                  left: 0,
                  width: 36,
                  height: _rowHeight,
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: i * _rowHeight,
                  left: 36,
                  right: 0,
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ],

              // 课程卡片
              for (final course in courses)
                _buildCourseCard(context, course, colWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    Course course,
    double colWidth,
  ) {
    final top = (course.startPeriod - 1) * _rowHeight + 2;
    final left = 36 + (course.dayOfWeek - 1) * colWidth + 1;
    final height = course.periodCount * _rowHeight - 4;
    final width = colWidth - 2;

    final color = _palette[course.colorIndex % _palette.length];

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => _showCourseDetail(context, course),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.15,
                ),
              ),
              const Spacer(),
              if (course.classroom.isNotEmpty)
                Text(
                  course.classroom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseDetail(BuildContext context, Course course) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _palette[course.colorIndex % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        course.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (course.credit > 0)
                      Chip(
                        label: Text('${course.credit} 学分'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('授课教师'),
                  subtitle: Text(
                    course.teacher.isNotEmpty ? course.teacher : '待定',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.room_outlined),
                  title: const Text('上课地点'),
                  subtitle: Text(
                    course.classroom.isNotEmpty ? course.classroom : '未知地点',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('节次时间'),
                  subtitle: Text(
                    '周${_WeekHeader._weekDays[course.dayOfWeek - 1]} 第${course.startPeriod}-${course.endPeriod}节',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_outlined),
                  title: const Text('周次范围'),
                  subtitle: Text(
                    '${course.weeks.map((w) => '$w').join(', ')} 周',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
