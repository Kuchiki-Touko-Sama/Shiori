import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/features/evaluation/evaluation_controller.dart';

/// 一键评教页面。
class EvaluationPage extends ConsumerStatefulWidget {
  const EvaluationPage({super.key});

  @override
  ConsumerState<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends ConsumerState<EvaluationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(evaluationControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('教学评价'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新评教列表',
            onPressed: state.isSubmitting
                ? null
                : () => ref
                    .read(evaluationControllerProvider.notifier)
                    .loadEvaluations(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(evaluationControllerProvider.notifier)
                  .loadEvaluations(),
              child: CustomScrollView(
                slivers: [
                  // 顶部概览与一键评教卡片
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildOverviewCard(context, state, colorScheme),
                    ),
                  ),

                  // 标签栏（待评教 / 已完成）
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(text: '待评教 (${state.pendingItems.length})'),
                          Tab(text: '已完成 (${state.completedItems.length})'),
                        ],
                      ),
                    ),
                  ),

                  // 对应列表
                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingList(context, state),
                        _buildCompletedList(context, state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    EvaluationState state,
    ColorScheme colorScheme,
  ) {
    final pendingCount = state.pendingItems.length;
    final totalCount = state.evaluations.length;
    final percent = (state.completionRate * 100).toInt();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rate_review_rounded,
                  color: colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  '评教任务概况',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCount == 0
                        ? colorScheme.primaryContainer
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pendingCount == 0 ? '全部已评' : '$pendingCount 门待评',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pendingCount == 0
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '完成进度：$percent%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${state.completedItems.length} / $totalCount 门',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.completionRate,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: pendingCount == 0 || state.isSubmitting
                    ? null
                    : () => _showBatchEvaluateDialog(context, state),
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.done_all_rounded),
                label: Text(
                  state.isSubmitting
                      ? '批量提交中 (${(state.currentEvaluatingIndex ?? 0) + 1}/$pendingCount)...'
                      : '一键好评全部未评课程',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList(BuildContext context, EvaluationState state) {
    final items = state.pendingItems;
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: Colors.green),
            SizedBox(height: 12),
            Text('所有课程均已完成评教！', style: TextStyle(fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildEvaluationCard(context, item, isPending: true);
      },
    );
  }

  Widget _buildCompletedList(BuildContext context, EvaluationState state) {
    final items = state.completedItems;
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无已评教记录', style: TextStyle(fontSize: 14)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildEvaluationCard(context, item, isPending: false);
      },
    );
  }

  Widget _buildEvaluationCard(
    BuildContext context,
    EvaluationItem item, {
    required bool isPending,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.courseName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.teacher,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  FilledButton.tonal(
                    onPressed: () => _showSingleEvaluateDialog(context, item),
                    child: const Text('评教'),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        '已评',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出单门评教对话框
  Future<void> _showSingleEvaluateDialog(
    BuildContext context,
    EvaluationItem item,
  ) async {
    final commentController = TextEditingController(
      text: '教学认真负责，讲课重点突出，启发性强。',
    );
    var selectedRating = 5;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('评价：${item.courseName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('任课教师：${item.teacher}'),
              const SizedBox(height: 12),
              const Text('评分档位：',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ratingChip('5分 (优秀)', 5, selectedRating, (val) {
                    setDialogState(() => selectedRating = val);
                  }),
                  _ratingChip('4分 (良好)', 4, selectedRating, (val) {
                    setDialogState(() => selectedRating = val);
                  }),
                  _ratingChip('3分 (中等)', 3, selectedRating, (val) {
                    setDialogState(() => selectedRating = val);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              const Text('主观评价：',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '请输入评语...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                final success = await ref
                    .read(evaluationControllerProvider.notifier)
                    .submitSingle(
                      item,
                      rating: selectedRating,
                      comment: commentController.text.trim(),
                    );
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '${item.courseName} 评教成功！'
                          : '${item.courseName} 评教失败，请重试',
                    ),
                  ),
                );
              },
              child: const Text('提交评价'),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出批量评教二次确认对话框
  Future<void> _showBatchEvaluateDialog(
    BuildContext context,
    EvaluationState state,
  ) async {
    final commentController = TextEditingController(
      text: '老师治学严谨，教学准备充分，讲课生动清晰，重点突出，受益良多。',
    );
    var selectedRating = 5;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('一键全选评教'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '即将为剩余 ${state.pendingItems.length} 门未评课程批量打分并提交评语：',
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text('统一评分档位：',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ratingChip('5分 (优秀)', 5, selectedRating, (val) {
                      setDialogState(() => selectedRating = val);
                    }),
                    _ratingChip('4分 (良好)', 4, selectedRating, (val) {
                      setDialogState(() => selectedRating = val);
                    }),
                    _ratingChip('3分 (中等)', 3, selectedRating, (val) {
                      setDialogState(() => selectedRating = val);
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('统一主观评价：',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '批量评语内容...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('开始一键评教'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final count =
          await ref.read(evaluationControllerProvider.notifier).submitAll(
                rating: selectedRating,
                comment: commentController.text.trim(),
              );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('一键评教完成，成功提交 $count 门课程！')),
      );
    }
  }

  Widget _ratingChip(
    String label,
    int score,
    int currentScore,
    ValueChanged<int> onSelected,
  ) {
    final isSelected = score == currentScore;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) onSelected(score);
      },
    );
  }
}
