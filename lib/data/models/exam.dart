/// 考试安排实体模型。
class ExamItem {
  const ExamItem({
    required this.id,
    required this.courseName,
    required this.examDate,
    required this.examTime,
    this.location = '',
    this.seatNumber = '',
    this.examType = '期末考试',
    this.credit,
    this.parsedDateTime,
  });

  factory ExamItem.fromMap(Map<String, dynamic> map) {
    return ExamItem(
      id: map['id'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      examDate: map['examDate'] as String? ?? '',
      examTime: map['examTime'] as String? ?? '',
      location: map['location'] as String? ?? '',
      seatNumber: map['seatNumber'] as String? ?? '',
      examType: map['examType'] as String? ?? '期末考试',
      credit: (map['credit'] as num?)?.toDouble(),
      parsedDateTime: map['parsedDateTime'] != null
          ? DateTime.tryParse(map['parsedDateTime'] as String)
          : null,
    );
  }

  /// 考试唯一 ID
  final String id;

  /// 考试科目名称
  final String courseName;

  /// 考试日期（例如 '2026-11-20'）
  final String examDate;

  /// 考试时间段（例如 '09:00 - 11:00'）
  final String examTime;

  /// 考场地点（例如 '第七教学楼 302'）
  final String location;

  /// 座位号
  final String seatNumber;

  /// 考试性质（例如 '期末考试'、'补考'、'重修'）
  final String examType;

  /// 学分
  final double? credit;

  /// 解析出的具体考试开始时间
  final DateTime? parsedDateTime;

  /// 距离考试剩余天数（已过考则为负数）
  int? get daysRemaining {
    if (parsedDateTime == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(
      parsedDateTime!.year,
      parsedDateTime!.month,
      parsedDateTime!.day,
    );
    return examDay.difference(today).inDays;
  }

  /// 是否已经考完
  bool get isFinished {
    if (parsedDateTime == null) return false;
    return DateTime.now().isAfter(parsedDateTime!);
  }

  ExamItem copyWith({
    String? id,
    String? courseName,
    String? examDate,
    String? examTime,
    String? location,
    String? seatNumber,
    String? examType,
    double? credit,
    DateTime? parsedDateTime,
  }) {
    return ExamItem(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      examDate: examDate ?? this.examDate,
      examTime: examTime ?? this.examTime,
      location: location ?? this.location,
      seatNumber: seatNumber ?? this.seatNumber,
      examType: examType ?? this.examType,
      credit: credit ?? this.credit,
      parsedDateTime: parsedDateTime ?? this.parsedDateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'courseName': courseName,
      'examDate': examDate,
      'examTime': examTime,
      'location': location,
      'seatNumber': seatNumber,
      'examType': examType,
      'credit': credit,
      'parsedDateTime': parsedDateTime?.toIso8601String(),
    };
  }
}
