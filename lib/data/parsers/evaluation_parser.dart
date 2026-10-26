import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shiori/data/models/evaluation.dart';

/// URP 评教页面与问卷解析器。
class EvaluationParser {
  const EvaluationParser();

  /// 解析 URP 评教列表页面 HTML 与 JSON
  List<EvaluationItem> parseList(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return _parseJsonList(trimmed);
      } on FormatException {
        // 不是有效 JSON，继续走 HTML 解析
      }
    }

    final document = html_parser.parse(trimmed);
    final items = <EvaluationItem>[];

    // 尝试寻找表头以确定列索引映射
    int? titleCol;
    int? courseCol;
    int? teacherCol;
    int? statusCol;

    final headerThs = document.querySelectorAll('table th');
    if (headerThs.isNotEmpty) {
      for (var i = 0; i < headerThs.length; i++) {
        final text = headerThs[i].text.trim();
        if (text.contains('问卷')) titleCol = i;
        if (text.contains('内容') || text.contains('课程')) courseCol = i;
        if (text.contains('人') || text.contains('教师')) teacherCol = i;
        if (text.contains('是否') || text.contains('状态')) statusCol = i;
      }
    }

    final rows = document.querySelectorAll('table tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 4) continue;

      final rowText = cells.map((c) => c.text.trim()).toList();
      final link = row.querySelector('a');
      final href = link?.attributes['href'] ?? '';

      // 提取 wjbm, bpr, pgnr
      var wjbm = _extractParam(href, 'wjbm');
      var bpr = _extractParam(href, 'bpr');
      var pgnr = _extractParam(href, 'pgnr');

      // 若未从 href 取到，尝试从 onClick/JS 函数提取
      final onClick = link?.attributes['onclick'] ?? '';
      if (wjbm.isEmpty && onClick.isNotEmpty) {
        final jsParams = _extractJsParams(onClick);
        if (jsParams.isNotEmpty) {
          wjbm = jsParams.isNotEmpty ? jsParams[0] : '';
          bpr = jsParams.length > 1 ? jsParams[1] : '';
          pgnr = jsParams.length > 2 ? jsParams[2] : '';
        }
      }

      // 判断评教状态
      var isEvaluated = false;
      if (statusCol != null && statusCol < rowText.length) {
        final st = rowText[statusCol];
        isEvaluated = st.contains('已') || st == '是';
      } else {
        final fullRowText = rowText.join(' ');
        isEvaluated = fullRowText.contains('已评估') ||
            fullRowText.contains('已评') ||
            (cells.any((c) => c.text.trim() == '是') &&
                !fullRowText.contains('未评估') &&
                !fullRowText.contains('否'));
      }

      final status = isEvaluated
          ? EvaluationStatus.completed
          : EvaluationStatus.pending;

      // 解析课程名称、教师、问卷标题
      String title;
      String courseName;
      String teacher;

      if (titleCol != null && titleCol < rowText.length) {
        title = rowText[titleCol];
      } else {
        title = cells.length >= 6 ? rowText[1] : rowText[0];
      }

      if (courseCol != null && courseCol < rowText.length) {
        courseName = rowText[courseCol];
      } else {
        courseName = cells.length >= 6 ? rowText[2] : rowText[1];
      }

      if (teacherCol != null && teacherCol < rowText.length) {
        teacher = rowText[teacherCol];
      } else {
        teacher = cells.length >= 6 ? rowText[3] : rowText[2];
      }

      // 如果依然缺失唯一参数，生成自增/文本兜底 ID
      if (wjbm.isEmpty && bpr.isEmpty && pgnr.isEmpty) {
        if (link == null && !isEvaluated) continue;
        wjbm = 'default_wj';
        bpr = teacher.isNotEmpty ? teacher : 'teacher_${items.length}';
        pgnr = courseName.isNotEmpty ? courseName : 'course_${items.length}';
      }

      final id = '${wjbm}_${bpr}_$pgnr';
      if (items.any((existing) => existing.id == id)) continue;

      items.add(
        EvaluationItem(
          id: id,
          title: title.isNotEmpty ? title : '教学质量评估问卷',
          courseName: courseName.isNotEmpty ? courseName : '未知课程',
          teacher: teacher.isNotEmpty ? teacher : '任课教师',
          wjbm: wjbm,
          bpr: bpr,
          pgnr: pgnr,
          status: status,
        ),
      );
    }

    return items;
  }

  /// 解析问卷详情 HTML，提取所有题目与单选题选项
  EvaluationQuestionnaire parseQuestionnaire(
    String html,
    EvaluationItem item,
  ) {
    final document = html_parser.parse(html);
    final questions = <EvaluationQuestion>[];

    // 查找防重 token 或隐藏域
    String? token;
    final tokenInput = document.querySelector('input[name="tokenValue"]') ??
        document.querySelector('input[name="token"]');
    if (tokenInput != null) {
      token = tokenInput.attributes['value'];
    }

    // 提取所有单选按钮
    final radios = document.querySelectorAll('input[type="radio"]');
    final radioGroups = <String, List<Element>>{};
    for (final radio in radios) {
      final name = radio.attributes['name'];
      if (name != null && name.isNotEmpty) {
        radioGroups.putIfAbsent(name, () => []).add(radio);
      }
    }

    // 遍历每一个题目组
    for (final entry in radioGroups.entries) {
      final name = entry.key;
      final elements = entry.value;

      // 提取题目题干：向上查找包含此 radio 的 tr 或 td 对应的文字描述
      var questionTitle = '指标项目 $name';
      final parentTr = _findAncestorTag(elements.first, 'tr');
      if (parentTr != null) {
        // 查找 tr 内不是 radio 选项的文本
        final text = parentTr.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.length > 3) {
          questionTitle = text;
        }
      }

      final options = <EvaluationOption>[];
      for (var i = 0; i < elements.length; i++) {
        final el = elements[i];
        final val = el.attributes['value'] ?? '${i + 1}';
        final score = 5 - i; // 默认第 1 个是 5 分/最高档，依次递减
        final optionName = _findOptionLabel(el) ?? _defaultOptionName(i);

        options.add(
          EvaluationOption(
            name: optionName,
            value: val,
            score: score,
          ),
        );
      }

      questions.add(
        EvaluationQuestion(
          id: name,
          title: questionTitle,
          options: options,
          selectedOptionValue: options.isNotEmpty ? options.first.value : null,
        ),
      );
    }

    return EvaluationQuestionnaire(
      item: item,
      questions: questions,
      token: token,
    );
  }

  /// 构建评教提交所需要的表单数据
  Map<String, String> buildSubmitPayload({
    required EvaluationQuestionnaire questionnaire,
    int targetScore = 5,
    String? comment,
  }) {
    final payload = <String, String>{
      'wjbm': questionnaire.item.wjbm,
      'bpr': questionnaire.item.bpr,
      'pgnr': questionnaire.item.pgnr,
      'zgpj': comment ?? questionnaire.defaultComment,
    };

    if (questionnaire.token != null) {
      payload['tokenValue'] = questionnaire.token!;
    }

    for (final question in questionnaire.questions) {
      if (question.options.isEmpty) continue;
      // 匹配分值最接近 targetScore 的选项，默认选第 1 个（最高档）
      final selected = question.options.firstWhere(
        (opt) => opt.score == targetScore,
        orElse: () => question.options.first,
      );
      payload[question.id] = selected.value;
    }

    return payload;
  }

  /// 从 URL 查询参数中提取 key 的值
  String _extractParam(String url, String key) {
    final regExp = RegExp('$key=([^&]*)');
    final match = regExp.firstMatch(url);
    return match?.group(1)?.trim() ?? '';
  }

  /// 从 JavaScript 调用字符串中提取参数（如 `wjShow('001', '1002', '12')`）
  List<String> _extractJsParams(String js) {
    final regExp = RegExp(r"['\x22]([^'\x22]+)['\x22]");
    final matches = regExp.allMatches(js);
    return matches.map((m) => m.group(1)?.trim() ?? '').toList();
  }

  Element? _findAncestorTag(Element element, String tagName) {
    var curr = element.parent;
    while (curr != null) {
      if (curr.localName?.toLowerCase() == tagName.toLowerCase()) {
        return curr;
      }
      curr = curr.parent;
    }
    return null;
  }

  String? _findOptionLabel(Element radio) {
    // 检查紧邻兄弟节点的文本
    final nextNode = radio.nextElementSibling;
    if (nextNode != null && nextNode.text.trim().isNotEmpty) {
      return nextNode.text.trim();
    }
    return null;
  }

  String _defaultOptionName(int index) {
    switch (index) {
      case 0:
        return '非常满意/优秀';
      case 1:
        return '满意/良好';
      case 2:
        return '基本满意/中等';
      case 3:
        return '一般/合格';
      default:
        return '不满意/不合格';
    }
  }

  /// 解析新版现代 URP 评教列表 JSON
  List<EvaluationItem> _parseJsonList(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    final items = <EvaluationItem>[];
    var rawList = <Map<String, dynamic>>[];

    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        rawList = (decoded['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else if (decoded['list'] is List) {
        rawList = (decoded['list'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else if (decoded['evaluationList'] is List) {
        rawList = (decoded['evaluationList'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } else if (decoded is List) {
      rawList = decoded.whereType<Map<String, dynamic>>().toList();
    }

    if (rawList.isEmpty) {
      void collect(dynamic data) {
        if (data is List) {
          data.forEach(collect);
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            collect(data['data']);
          } else if (data.containsKey('list') && data['list'] is List) {
            collect(data['list']);
          } else if (data.containsKey('evaluationContent') ||
              data.containsKey('evaluatedPeople') ||
              data.containsKey('kcm') ||
              data.containsKey('courseName') ||
              data.containsKey('wjmc')) {
            rawList.add(data);
          }
        }
      }

      collect(decoded);
    }

    for (final m in rawList) {
      // 1. 课程名称
      final courseName = (m['evaluationContent'] ??
              m['courseName'] ??
              m['kcm'] ??
              m['pgnr'] ??
              '')
          .toString()
          .trim();

      // 2. 被评教师姓名
      var teacher = '';
      if (m['evaluatedPeople'] is String) {
        final ep = (m['evaluatedPeople'] as String).trim();
        // 如果不是纯数字（不是工号代码），即为教师真实姓名
        if (ep.isNotEmpty && !RegExp(r'^\d+$').hasMatch(ep)) {
          teacher = ep;
        }
      }
      if (teacher.isEmpty) {
        teacher = (m['teacher'] ??
                m['teacherName'] ??
                m['bpr'] ??
                m['jsm'] ??
                '')
            .toString()
            .trim();
      }
      teacher = teacher.replaceAll('*', '').trim();

      // 3. 问卷标题 / 类型
      var title = '';
      if (m['questionnaire'] is Map) {
        final qm = m['questionnaire'] as Map;
        title = (qm['questionnaireName'] ?? '').toString().trim();
      }
      if (title.isEmpty) {
        title = (m['wjmc'] ??
                m['title'] ??
                (courseName.isNotEmpty ? '$courseName 评教' : '教学质量评估问卷'))
            .toString()
            .trim();
      }

      // 4. 关键参数（wjbm, bpr, pgnr）
      var wjbm = '';
      var bpr = '';
      var pgnr = '';

      if (m['id'] is Map) {
        final idMap = m['id'] as Map;
        wjbm = (idMap['questionnaireCoding'] ?? '').toString().trim();
        bpr = (idMap['evaluatedPeople'] ?? '').toString().trim();
        pgnr = (idMap['evaluationContentNumber'] ?? '').toString().trim();
      }

      if (wjbm.isEmpty && m['questionnaire'] is Map) {
        final qm = m['questionnaire'] as Map;
        wjbm = (qm['questionnaireNumber'] ?? '').toString().trim();
      }
      if (wjbm.isEmpty) {
        wjbm = (m['wjbm'] ?? m['questionnaireCode'] ?? '').toString().trim();
      }
      if (bpr.isEmpty) {
        bpr = (m['bpr'] ?? m['teacherCode'] ?? '').toString().trim();
      }
      if (pgnr.isEmpty) {
        pgnr = (m['pgnr'] ?? m['courseCode'] ?? '').toString().trim();
      }

      // 5. 评教状态
      final dynamic statusVal =
          m['isEvaluated'] ?? m['status'] ?? m['sfpg'] ?? m['state'] ?? '';
      final statusStr = statusVal.toString().trim();
      final isEvaluated = statusStr.contains('已') ||
          statusStr == '1' ||
          statusStr == '是' ||
          statusStr.toLowerCase() == 'true' ||
          statusVal == true;

      final mId = m['id'];
      final seq = (mId is Map ? (mId['coureSequenceNumber'] ?? '') : '')
          .toString()
          .trim();
      final seqSuffix = seq.isNotEmpty ? '_$seq' : '';
      final id = (wjbm.isNotEmpty || bpr.isNotEmpty || pgnr.isNotEmpty)
          ? '${wjbm}_${bpr}_$pgnr$seqSuffix'
          : '${courseName}_${teacher}_${items.length}';

      if (items.any((existing) => existing.id == id)) continue;

      items.add(
        EvaluationItem(
          id: id,
          title: title,
          courseName: courseName.isNotEmpty ? courseName : title,
          teacher: teacher.isNotEmpty ? teacher : '任课教师',
          status: isEvaluated
              ? EvaluationStatus.completed
              : EvaluationStatus.pending,
          wjbm: wjbm,
          bpr: bpr,
          pgnr: pgnr,
        ),
      );
    }

    return items;
  }
}
