/// 评教状态枚举
enum EvaluationStatus {
  /// 未评
  pending('未评估'),

  /// 已评
  completed('已评估');

  EvaluationStatus(this.label);
  final String label;
}

/// 评教单项模型
class EvaluationItem {
  const EvaluationItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.teacher,
    required this.wjbm,
    required this.bpr,
    required this.pgnr,
    this.status = EvaluationStatus.pending,
  });

  factory EvaluationItem.fromMap(Map<String, dynamic> map) {
    return EvaluationItem(
      id: map['id'] as String,
      title: map['title'] as String,
      courseName: map['courseName'] as String,
      teacher: map['teacher'] as String,
      wjbm: map['wjbm'] as String,
      bpr: map['bpr'] as String,
      pgnr: map['pgnr'] as String,
      status: map['status'] == 'completed'
          ? EvaluationStatus.completed
          : EvaluationStatus.pending,
    );
  }

  /// 唯一标识（通常为 wjbm_bpr_pgnr）
  final String id;

  /// 问卷名称（如：课堂教学质量评估学生问卷）
  final String title;

  /// 课程名称
  final String courseName;

  /// 被评教师
  final String teacher;

  /// 问卷编码
  final String wjbm;

  /// 被评人/教师代码
  final String bpr;

  /// 评估内容/课程代码
  final String pgnr;

  /// 评教状态
  final EvaluationStatus status;

  bool get isCompleted => status == EvaluationStatus.completed;

  EvaluationItem copyWith({
    String? id,
    String? title,
    String? courseName,
    String? teacher,
    String? wjbm,
    String? bpr,
    String? pgnr,
    EvaluationStatus? status,
  }) {
    return EvaluationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      courseName: courseName ?? this.courseName,
      teacher: teacher ?? this.teacher,
      wjbm: wjbm ?? this.wjbm,
      bpr: bpr ?? this.bpr,
      pgnr: pgnr ?? this.pgnr,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseName': courseName,
      'teacher': teacher,
      'wjbm': wjbm,
      'bpr': bpr,
      'pgnr': pgnr,
      'status': status.name,
    };
  }
}

/// 评教问卷选项
class EvaluationOption {
  const EvaluationOption({
    required this.name,
    required this.value,
    required this.score,
  });

  /// 选项显示名称（例如：优秀、非常满意、很赞同）
  final String name;

  /// 提交给表单的值（例如：10_1 或 10）
  final String value;

  /// 对应分值
  final int score;
}

/// 评教问卷单道题目
class EvaluationQuestion {
  const EvaluationQuestion({
    required this.id,
    required this.title,
    required this.options,
    this.selectedOptionValue,
  });

  /// 题目输入项名称（如：0000000021 等 radio name）
  final String id;

  /// 题目文本（如：治学严谨，教学准备充分）
  final String title;

  /// 可选选项列表
  final List<EvaluationOption> options;

  /// 当前选中的选项值
  final String? selectedOptionValue;

  EvaluationQuestion copyWith({
    String? id,
    String? title,
    List<EvaluationOption>? options,
    String? selectedOptionValue,
  }) {
    return EvaluationQuestion(
      id: id ?? this.id,
      title: title ?? this.title,
      options: options ?? this.options,
      selectedOptionValue: selectedOptionValue ?? this.selectedOptionValue,
    );
  }
}

/// 问卷详情模型（包含所有题目与防重 token）
class EvaluationQuestionnaire {
  const EvaluationQuestionnaire({
    required this.item,
    required this.questions,
    this.token,
    this.defaultComment = '教学认真负责，讲课重点突出，启发性强。',
  });

  final EvaluationItem item;
  final List<EvaluationQuestion> questions;
  final String? token;
  final String defaultComment;
}
