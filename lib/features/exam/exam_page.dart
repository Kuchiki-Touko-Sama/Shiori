import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/models/exam.dart';
import 'package:shiori/features/exam/exam_controller.dart';
import 'package:shiori/shared/widgets/frosted_app_bar.dart';

/// 考试安排页面。
class ExamPage extends ConsumerWidget {
  const ExamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: frostedFlexibleSpace(context),
        title: const Text('考试安排'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新考试安排',
            onPressed: () {
              unawaited(
                ref
                    .read(examControllerProvider.notifier)
                    .loadExams(forceRefresh: true),
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
            .read(examControllerProvider.notifier)
            .loadExams(forceRefresh: true),
        child: state.exams.isEmpty && !state.isLoading
            ? _buildEmptyView(context, scheme)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: state.exams.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final exam = state.exams[index];
                  return _ExamCard(exam: exam);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 64,
                color: scheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无考试安排',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '教务系统暂未排布近期考试，下拉可重新获取',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});

  final ExamItem exam;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = exam.daysRemaining;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam.courseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _buildCountdownBadge(scheme, days),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.access_time,
              text: exam.examTime,
              scheme: scheme,
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              text: exam.location.isNotEmpty ? exam.location : '考场待定',
              scheme: scheme,
            ),
            if (exam.seatNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildDetailRow(
                icon: Icons.event_seat_outlined,
                text: '座位号：${exam.seatNumber} 号',
                scheme: scheme,
              ),
            ],
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: Icons.assignment_outlined,
              text: exam.examType,
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownBadge(ColorScheme scheme, int? days) {
    if (exam.isFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '已考完',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      );
    }

    if (days != null) {
      if (days == 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '今天开考',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onErrorContainer,
            ),
          ),
        );
      } else if (days > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '还有 $days 天',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exam.examType,
        style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String text,
    required ColorScheme scheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
