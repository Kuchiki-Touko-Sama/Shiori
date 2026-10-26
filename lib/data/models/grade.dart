/// 成绩实体模型。
class GradeItem {
  const GradeItem({
    required this.id,
    required this.courseName,
    required this.credit,
    required this.rawScore,
    this.score,
    this.gradePoint = 0.0,
    this.courseType = '必修',
    this.semester = '',
    this.examType = '正常考试',
  });

  factory GradeItem.fromMap(Map<String, dynamic> map) {
    return GradeItem(
      id: map['id'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      rawScore: map['rawScore'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble(),
      gradePoint: (map['gradePoint'] as num?)?.toDouble() ?? 0.0,
      courseType: map['courseType'] as String? ?? '必修',
      semester: map['semester'] as String? ?? '',
      examType: map['examType'] as String? ?? '正常考试',
    );
  }

  /// 成绩条目唯一标识
  final String id;

  /// 课程名称
  final String courseName;

  /// 学分
  final double credit;

  /// 教务原始成绩字符串（例如 '88', '优秀', '及格'）
  final String rawScore;

  /// 折算后的百分制数值（用于加权均分计算）
  final double? score;

  /// 教务给出的绩点（若有）
  final double gradePoint;

  /// 课程性质（必修 / 选修 / 公选 / 实践等）
  final String courseType;

  /// 所在学年学期（例如 '2025-2026-1'）
  final String semester;

  /// 考试性质（正常考试 / 补考 / 重修）
  final String examType;

  /// 是否及格通过
  bool get isPassed {
    if (score != null) {
      return score! >= 60;
    }
    final lower = rawScore.trim().toLowerCase();
    return !lower.contains('不及格') &&
        !lower.contains('不合格') &&
        lower != 'f' &&
        lower != '0';
  }

  GradeItem copyWith({
    String? id,
    String? courseName,
    double? credit,
    String? rawScore,
    double? score,
    double? gradePoint,
    String? courseType,
    String? semester,
    String? examType,
  }) {
    return GradeItem(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      credit: credit ?? this.credit,
      rawScore: rawScore ?? this.rawScore,
      score: score ?? this.score,
      gradePoint: gradePoint ?? this.gradePoint,
      courseType: courseType ?? this.courseType,
      semester: semester ?? this.semester,
      examType: examType ?? this.examType,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'courseName': courseName,
      'credit': credit,
      'rawScore': rawScore,
      'score': score,
      'gradePoint': gradePoint,
      'courseType': courseType,
      'semester': semester,
      'examType': examType,
    };
  }
}
