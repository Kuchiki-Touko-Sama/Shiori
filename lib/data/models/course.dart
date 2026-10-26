/// 课程实体模型。
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    this.teacher = '',
    this.classroom = '',
    this.credit = 0.0,
    this.colorIndex = 0,
    this.rawTimeStr = '',
  }) : assert(
          dayOfWeek >= 1 && dayOfWeek <= 7,
          'dayOfWeek 必须在 1 到 7 之间（1=周一）',
        ),
        assert(
          startPeriod >= 1 && endPeriod >= startPeriod,
          'startPeriod 必须 >= 1 且 endPeriod 必须 >= startPeriod',
        );

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      classroom: map['classroom'] as String? ?? '',
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt() ?? 1,
      startPeriod: (map['startPeriod'] as num?)?.toInt() ?? 1,
      endPeriod: (map['endPeriod'] as num?)?.toInt() ?? 2,
      weeks: (map['weeks'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          <int>[],
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
      rawTimeStr: map['rawTimeStr'] as String? ?? '',
    );
  }

  /// 课程唯一标识（课程代码或哈希）
  final String id;

  /// 课程名称
  final String name;

  /// 授课教师
  final String teacher;

  /// 上课教室
  final String classroom;

  /// 星期几（1 = 周一, ..., 7 = 周日）
  final int dayOfWeek;

  /// 起始节次（1..12）
  final int startPeriod;

  /// 结束节次（1..12）
  final int endPeriod;

  /// 上课周次列表（例如 [1, 2, 3, 4, 5, 6, 7, 8]）
  final List<int> weeks;

  /// 学分
  final double credit;

  /// 调色板颜色索引（用于分配主题色调）
  final int colorIndex;

  /// 教务系统原始时间地点字符串
  final String rawTimeStr;

  /// 本节课程持续的节数
  int get periodCount => endPeriod - startPeriod + 1;

  /// 判断指定周次是否需要上课
  bool isActiveInWeek(int week) => weeks.contains(week);

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    int? dayOfWeek,
    int? startPeriod,
    int? endPeriod,
    List<int>? weeks,
    double? credit,
    int? colorIndex,
    String? rawTimeStr,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      weeks: weeks ?? this.weeks,
      credit: credit ?? this.credit,
      colorIndex: colorIndex ?? this.colorIndex,
      rawTimeStr: rawTimeStr ?? this.rawTimeStr,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'teacher': teacher,
      'classroom': classroom,
      'dayOfWeek': dayOfWeek,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'weeks': weeks,
      'credit': credit,
      'colorIndex': colorIndex,
      'rawTimeStr': rawTimeStr,
    };
  }
}
