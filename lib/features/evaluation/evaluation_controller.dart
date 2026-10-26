import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/models/evaluation.dart';

/// 评教页面状态
class EvaluationState {
  const EvaluationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.evaluations = const [],
    this.currentEvaluatingIndex,
    this.errorMessage,
    this.lastSuccessCount,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<EvaluationItem> evaluations;
  final int? currentEvaluatingIndex;
  final String? errorMessage;
  final int? lastSuccessCount;

  List<EvaluationItem> get pendingItems =>
      evaluations.where((e) => !e.isCompleted).toList();

  List<EvaluationItem> get completedItems =>
      evaluations.where((e) => e.isCompleted).toList();

  double get completionRate => evaluations.isEmpty
      ? 1.0
      : completedItems.length / evaluations.length;

  EvaluationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<EvaluationItem>? evaluations,
    int? currentEvaluatingIndex,
    bool clearEvaluatingIndex = false,
    String? errorMessage,
    int? lastSuccessCount,
  }) {
    return EvaluationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      evaluations: evaluations ?? this.evaluations,
      currentEvaluatingIndex: clearEvaluatingIndex
          ? null
          : (currentEvaluatingIndex ?? this.currentEvaluatingIndex),
      errorMessage: errorMessage,
      lastSuccessCount: lastSuccessCount ?? this.lastSuccessCount,
    );
  }
}

/// 评教业务控制器
class EvaluationController extends Notifier<EvaluationState> {
  @override
  EvaluationState build() {
    unawaited(Future.microtask(loadEvaluations));
    return const EvaluationState();
  }

  /// 加载评教任务列表
  Future<void> loadEvaluations() async {
    state = state.copyWith(isLoading: true);
    try {
      final gateway = ref.read(hbuUrpGatewayProvider);
      final list = await gateway.getEvaluations();
      state = state.copyWith(
        isLoading: false,
        evaluations: list,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载评教列表失败: $e',
      );
    }
  }

  /// 提交单门课程评教
  Future<bool> submitSingle(
    EvaluationItem item, {
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
  }) async {
    try {
      final gateway = ref.read(hbuUrpGatewayProvider);
      final success = await gateway.submitEvaluation(
        item,
        rating: rating,
        comment: comment,
      );
      if (success) {
        final updated = state.evaluations.map((e) {
          if (e.id == item.id) {
            return e.copyWith(status: EvaluationStatus.completed);
          }
          return e;
        }).toList();
        state = state.copyWith(evaluations: updated);
        return true;
      }
      return false;
    } on Exception catch (e) {
      state = state.copyWith(errorMessage: '评教提交失败: $e');
      return false;
    }
  }

  /// 一键批量评教所有未评课程
  Future<int> submitAll({
    int rating = 5,
    String comment = '教学认真负责，讲课重点突出，启发性强。',
    void Function(int current, int total)? onProgress,
  }) async {
    final pending = state.pendingItems;
    if (pending.isEmpty) return 0;

    state = state.copyWith(
      isSubmitting: true,
      currentEvaluatingIndex: 0,
    );

    var successCount = 0;
    final currentList = List<EvaluationItem>.from(state.evaluations);
    final gateway = ref.read(hbuUrpGatewayProvider);

    for (var i = 0; i < pending.length; i++) {
      final item = pending[i];
      state = state.copyWith(currentEvaluatingIndex: i);
      onProgress?.call(i + 1, pending.length);

      try {
        final ok = await gateway.submitEvaluation(
          item,
          rating: rating,
          comment: comment,
        );
        if (ok) {
          successCount++;
          final idx = currentList.indexWhere((e) => e.id == item.id);
          if (idx != -1) {
            currentList[idx] =
                item.copyWith(status: EvaluationStatus.completed);
          }
        }
      } on Exception catch (_) {
        // 单项失败不阻断后续项
      }
    }

    state = state.copyWith(
      isSubmitting: false,
      clearEvaluatingIndex: true,
      evaluations: currentList,
      lastSuccessCount: successCount,
    );

    return successCount;
  }
}

/// EvaluationController Provider
final evaluationControllerProvider =
    NotifierProvider<EvaluationController, EvaluationState>(
  EvaluationController.new,
);
