import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/data/models/evaluation.dart';
import 'package:shiori/data/parsers/evaluation_parser.dart';

void main() {
  group('EvaluationParser 评教列表与问卷解析测试', () {
    const parser = EvaluationParser();

    test('解析典型 URP 评教列表 HTML', () {
      const html = '''
<!DOCTYPE html>
<html>
<body>
<table class="displayTag">
  <thead>
    <tr>
      <th>序号</th>
      <th>问卷名称</th>
      <th>评估内容</th>
      <th>被评估人</th>
      <th>是否评估</th>
      <th>评估</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>本科生课堂教学质量评估学生问卷</td>
      <td>高等数学(上)</td>
      <td>李教授</td>
      <td>否</td>
      <td><a href="jxpgXsAction.do?oper=wjShow&wjbm=0000000041&bpr=1001&pgnr=0001">评估</a></td>
    </tr>
    <tr>
      <td>2</td>
      <td>本科生课堂教学质量评估学生问卷</td>
      <td>大学物理实验</td>
      <td>实验教学组</td>
      <td>是</td>
      <td>已评估</td>
    </tr>
  </tbody>
</table>
</body>
</html>
''';

      final items = parser.parseList(html);
      expect(items.length, 2);

      // 第一项：待评
      final item1 = items[0];
      expect(item1.courseName, '高等数学(上)');
      expect(item1.teacher, '李教授');
      expect(item1.wjbm, '0000000041');
      expect(item1.bpr, '1001');
      expect(item1.pgnr, '0001');
      expect(item1.status, EvaluationStatus.pending);
      expect(item1.isCompleted, isFalse);

      // 第二项：已评
      final item2 = items[1];
      expect(item2.courseName, '大学物理实验');
      expect(item2.teacher, '实验教学组');
      expect(item2.status, EvaluationStatus.completed);
      expect(item2.isCompleted, isTrue);
    });

    test('解析支持 JavaScript onClick 的评教行', () {
      const html = '''
<table>
  <tr>
    <td>1</td>
    <td>课堂评估</td>
    <td>数据结构与算法</td>
    <td>张老师</td>
    <td>未评估</td>
    <td><a href="#" onclick="javascript:openWj('wj999', 'teach88', 'course77');">立即评价</a></td>
  </tr>
</table>
''';

      final items = parser.parseList(html);
      expect(items.length, 1);
      final item = items.first;
      expect(item.courseName, '数据结构与算法');
      expect(item.teacher, '张老师');
      expect(item.wjbm, 'wj999');
      expect(item.bpr, 'teach88');
      expect(item.pgnr, 'course77');
      expect(item.status, EvaluationStatus.pending);
    });

    test('解析问卷详情题目与构建一键好评表单', () {
      const questionnaireHtml = '''
<form name="form1" action="jxpgXsAction.do?oper=wjf" method="post">
  <input type="hidden" name="tokenValue" value="secret_csrf_token_999">
  <table>
    <tr>
      <td>1. 治学严谨，备课充分，按时上下课</td>
      <td>
        <input type="radio" name="0000000021" value="10_1"><span>非常满意</span>
        <input type="radio" name="0000000021" value="10_0.8"><span>满意</span>
        <input type="radio" name="0000000021" value="10_0.6"><span>一般</span>
      </td>
    </tr>
    <tr>
      <td>2. 讲课生动条理清晰，注重互动与启发</td>
      <td>
        <input type="radio" name="0000000022" value="20_1"><span>非常满意</span>
        <input type="radio" name="0000000022" value="20_0.8"><span>满意</span>
      </td>
    </tr>
  </table>
  <textarea name="zgpj"></textarea>
</form>
''';

      const item = EvaluationItem(
        id: 'wj01_1001_c01',
        title: '问卷测试',
        courseName: '操作系统',
        teacher: '赵老师',
        wjbm: 'wj01',
        bpr: '1001',
        pgnr: 'c01',
      );

      final questionnaire = parser.parseQuestionnaire(questionnaireHtml, item);
      expect(questionnaire.token, 'secret_csrf_token_999');
      expect(questionnaire.questions.length, 2);
      expect(questionnaire.questions[0].id, '0000000021');
      expect(questionnaire.questions[0].options.length, 3);
      expect(questionnaire.questions[0].options.first.score, 5);

      // 构建提交表单
      final payload = parser.buildSubmitPayload(
        questionnaire: questionnaire,
        comment: '老师授课细致，受益匪浅。',
      );

      expect(payload['wjbm'], 'wj01');
      expect(payload['bpr'], '1001');
      expect(payload['pgnr'], 'c01');
      expect(payload['tokenValue'], 'secret_csrf_token_999');
      expect(payload['0000000021'], '10_1');
      expect(payload['0000000022'], '20_1');
      expect(payload['zgpj'], '老师授课细致，受益匪浅。');
    });
  });
}
