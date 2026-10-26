import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/network/cookie_jar_provider.dart';
import 'package:shiori/core/network/webvpn_interceptor.dart';
import 'package:shiori/core/session/session_manager.dart';
import 'package:shiori/core/transport/webvpn_url.dart';
import 'package:shiori/data/gateway/hbu_urp_gateway.dart';
import 'package:shiori/data/parsers/evaluation_parser.dart';
import 'package:shiori/data/parsers/exam_parser.dart';
import 'package:shiori/data/parsers/grade_parser.dart';
import 'package:shiori/data/parsers/timetable_parser.dart';
import 'package:shiori/features/evaluation/evaluation_controller.dart';
import 'package:shiori/features/exam/exam_controller.dart';
import 'package:shiori/features/grades/grades_controller.dart';
import 'package:shiori/features/timetable/timetable_controller.dart';
import 'package:shiori/shared/widgets/frosted_app_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebVPN 官方认证登录页面。
///
/// 通过 WebView 加载河北大学 WebVPN（v.hbu.cn）官方统一认证或直接进入
/// 本科教务系统（zhjw.hbu.cn）。
/// 支持智能 DOM 探针自动识别「URP高校教务管理系统」与「欢迎您，XXX」，
/// 并提供悬浮手动同步逃逸通道，实现稳定、鲁棒的会话跨域桥接。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const String initialUrl = 'https://v.hbu.cn/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  WebViewController? _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  bool _isLoading = true;
  double _progress = 0;
  bool _isSyncing = false;
  bool _isUrpDetected = false;
  String? _detectedUsername;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    unawaited(_initWebView());
  }

  Future<void> _initWebView() async {
    // 单元测试或桌面环境可能未注册 WebViewPlatform，提供安全兜底
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress / 100.0;
            });
          }
        },
        onPageStarted: (url) {
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
          }
        },
        onPageFinished: (url) async {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          await _handlePageFinished(url);
        },
      ),
    );
    await controller.loadRequest(Uri.parse(LoginPage.initialUrl));

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  /// 检查页面内容、DOM 特征与 Cookie，判断是否已认证成功进入教务系统。
  Future<void> _handlePageFinished(String url) async {
    if (_isSyncing) return;

    var probedUrp = false;
    String? probedName;

    // 1. 注入 JavaScript 探针探测页面特征（支持新版 URP 教务系统）
    if (_controller != null) {
      try {
        final jsProbe = await _controller!.runJavaScriptReturningResult(
          r'''
          (function() {
            var body = document.body ? document.body.innerText : '';
            var title = document.title || '';
            var m = body.match(/欢迎您[，,:：\s]*([^\s\n\r<,，!！]+)/);
            var username = m ? m[1] : '';
            if (!username) {
              var el = document.querySelector('.user-name, #username, .name, .userInfo');
              if (el) username = el.innerText.trim();
            }
            var isUrp = title.indexOf('URP') !== -1 ||
                        body.indexOf('URP高校教务管理系统') !== -1 ||
                        body.indexOf('主修/辅修方案管理') !== -1 ||
                        body.indexOf('我的待办任务') !== -1;
            return JSON.stringify({
              isUrp: isUrp,
              username: username
            });
          })()
          ''',
        );

        final rawString = jsProbe.toString();
        // 剥离可能外层包裹的字符串引号
        var cleanJson = rawString;
        if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
          cleanJson = jsonDecode(cleanJson) as String;
        }

        final dynamic decoded = jsonDecode(cleanJson);
        if (decoded is Map<String, dynamic>) {
          probedUrp = decoded['isUrp'] == true;
          final uname = (decoded['username'] as String? ?? '').trim();
          if (uname.isNotEmpty) {
            probedName = uname;
          }
        }
      } on Exception {
        // JS 探针偶发异常不影响基础流程
      }
    }

    if (mounted && probedUrp != _isUrpDetected) {
      setState(() {
        _isUrpDetected = probedUrp;
        if (probedName != null) _detectedUsername = probedName;
      });
    }

    // 2. 判断是否满足登录成功条件
    // 特征 A: 页面 DOM 明确包含 URP 教务系统特征（如「欢迎您，赵睿哲」或「URP高校教务管理系统」）
    // 特征 B: WebVPN 门户已加载完成，并成功签发会话凭据
    final lowerUrl = url.toLowerCase();
    final isCasAuth = lowerUrl.contains('sso.hbu.cn') ||
        (lowerUrl.contains('v.hbu.cn/login') && !probedUrp);

    if (probedUrp) {
      // 在教务系统同源环境中，自动嗅探菜单并携带 vpnPrefix 抓取课表与考试数据
      if (_controller != null) {
        try {
          final jsProbeResult = await _controller!.runJavaScriptReturningResult(
            '''
            (async function() {
              var prefixMatch = location.pathname.match(new RegExp('^(/https?-[0-9]+/[^/]+|/https?/[^/]+)'));
              var vpnPrefix = prefixMatch ? prefixMatch[1] : '';

              // 候选端点列表（均拼装真实的 vpnPrefix）
              var scheduleUrls = [
                vpnPrefix + '/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/curr/callback',
                vpnPrefix + '/student/courseSelect/thisSemesterCurriculum/ajaxStudentSchedule/callback',
                vpnPrefix + '/student/courseSelect/calendarSchedule/index',
                vpnPrefix + '/student/courseSelect/thisSemesterCurriculum/index'
              ];
              var examUrls = [
                vpnPrefix + '/student/examination/examArrangement/index',
                vpnPrefix + '/student/examination/examArrangement/data',
                vpnPrefix + '/ksAction.do?actionType=7'
              ];
              var gradeUrls = [
                vpnPrefix + '/student/integratedQuery/scoreQuery/allPassingScores/index',
                vpnPrefix + '/student/integratedQuery/scoreQuery/allTermScores/index',
                vpnPrefix + '/student/integratedQuery/scoreQuery/thisTermScores/index'
              ];
              var evalUrls = [
                vpnPrefix + '/student/teachingEvaluation/teachingEvaluation/search',
                vpnPrefix + '/student/teachingEvaluation/evaluation/index'
              ];

              // 1. 从浏览器资源性能时序中嗅探已执行的 Ajax 请求（如有直接命中）
              try {
                var perfEntries = (window.performance && window.performance.getEntriesByType)
                    ? window.performance.getEntriesByType('resource')
                    : [];
                for (var p = 0; p < perfEntries.length; p++) {
                  var pUrl = perfEntries[p].name || '';
                  if (pUrl.indexOf('ajaxStudentSchedule') !== -1 && scheduleUrls.indexOf(pUrl) === -1) {
                    scheduleUrls.unshift(pUrl);
                  }
                  if (pUrl.indexOf('examArrangement') !== -1 && examUrls.indexOf(pUrl) === -1) {
                    examUrls.unshift(pUrl);
                  }
                  if ((pUrl.indexOf('allPassingScores') !== -1 || pUrl.indexOf('scoreQuery') !== -1) && gradeUrls.indexOf(pUrl) === -1) {
                    gradeUrls.unshift(pUrl);
                  }
                  if ((pUrl.indexOf('teachingEvaluation') !== -1 || pUrl.indexOf('evaluation') !== -1) && evalUrls.indexOf(pUrl) === -1) {
                    evalUrls.unshift(pUrl);
                  }
                }
              } catch (e) {}

              // 2. 访问课表主页与成绩主页嗅探页面内嵌的动态 Token
              try {
                var indexRes = await fetch(vpnPrefix + '/student/courseSelect/thisSemesterCurriculum/index', { credentials: 'include' });
                if (indexRes.ok) {
                  var indexHtml = await indexRes.text();
                  var mToken = indexHtml.match(new RegExp('thisSemesterCurriculum/([a-zA-Z0-9_-]+)/ajaxStudentSchedule'));
                  if (mToken && mToken[1]) {
                    var token = mToken[1];
                    scheduleUrls.unshift(vpnPrefix + '/student/courseSelect/thisSemesterCurriculum/' + token + '/ajaxStudentSchedule/curr/callback');
                  }
                }
              } catch (e) {}

              try {
                var scoreIndexRes = await fetch(vpnPrefix + '/student/integratedQuery/scoreQuery/allPassingScores/index', { credentials: 'include' });
                if (scoreIndexRes.ok) {
                  var scoreIndexHtml = await scoreIndexRes.text();
                  var mScoreToken = scoreIndexHtml.match(new RegExp('scoreQuery/([a-zA-Z0-9_-]+)/allPassingScores/callback'));
                  if (mScoreToken && mScoreToken[1]) {
                    var sToken = mScoreToken[1];
                    gradeUrls.unshift(vpnPrefix + '/student/integratedQuery/scoreQuery/' + sToken + '/allPassingScores/callback');
                  }
                }
              } catch (e) {}

              // 3. 智能扫描页面上的所有链接与菜单
              document.querySelectorAll('a, [url], [data-url]').forEach(function(el) {
                var text = (el.innerText || el.textContent || '').trim();
                var href = el.getAttribute('href') || el.getAttribute('url') || el.getAttribute('data-url') || '';
                if (href && href !== '#' && href.indexOf('javascript') === -1) {
                  var full = href.startsWith('http') ? href : (href.startsWith('/') ? (vpnPrefix + href) : (vpnPrefix + '/' + href));
                  if (text.indexOf('课表') !== -1 && scheduleUrls.indexOf(full) === -1) scheduleUrls.unshift(full);
                  if (text.indexOf('考试') !== -1 && examUrls.indexOf(full) === -1) examUrls.unshift(full);
                  if (text.indexOf('成绩') !== -1 && gradeUrls.indexOf(full) === -1) gradeUrls.unshift(full);
                  if ((text.indexOf('评教') !== -1 || text.indexOf('评估') !== -1) && evalUrls.indexOf(full) === -1) evalUrls.unshift(full);
                }
              });

              var scheduleData = '';
              for (var i = 0; i < scheduleUrls.length; i++) {
                try {
                  var sUrl = scheduleUrls[i];
                  var isAjax = sUrl.indexOf('ajaxStudentSchedule') !== -1;

                  // 若是 ajax 接口，优先使用 POST 请求并附带 XMLHttpRequest 标头
                  if (isAjax) {
                    var postRes = await fetch(sUrl, {
                      method: 'POST',
                      credentials: 'include',
                      headers: {
                        'Accept': 'application/json, text/javascript, */*; q=0.01',
                        'X-Requested-With': 'XMLHttpRequest'
                      }
                    });
                    if (postRes.ok) {
                      var tPost = await postRes.text();
                      if (tPost && tPost.length > 50 && (tPost.indexOf('selectCourseList') !== -1 || tPost.indexOf('dateList') !== -1 || tPost.indexOf('xkxx') !== -1 || tPost.indexOf('courseName') !== -1)) {
                        scheduleData = tPost;
                        break;
                      }
                    }
                  }

                  // 常规 GET 请求
                  var res = await fetch(sUrl, { credentials: 'include' });
                  if (res.ok) {
                    var t = await res.text();
                    if (t && t.length > 50 && (t.indexOf('course') !== -1 || t.indexOf('selectCourseList') !== -1 || t.indexOf('dateList') !== -1 || t.indexOf('kcm') !== -1 || t.indexOf('table') !== -1 || t.indexOf('xkxx') !== -1)) {
                      scheduleData = t;
                      break;
                    }
                  }
                } catch (e) {}
              }

              var examData = '';
              for (var j = 0; j < examUrls.length; j++) {
                try {
                  var eUrl = examUrls[j];
                  if (eUrl.indexOf('/data') !== -1) {
                    var postE = await fetch(eUrl, {
                      method: 'POST',
                      credentials: 'include',
                      headers: {
                        'Accept': 'application/json, text/javascript, */*; q=0.01',
                        'X-Requested-With': 'XMLHttpRequest'
                      }
                    });
                    if (postE.ok) {
                      var tE = await postE.text();
                      if (tE && tE.length > 50) {
                        examData = tE;
                        break;
                      }
                    }
                  }

                  var r2 = await fetch(eUrl, { credentials: 'include' });
                  if (r2.ok) {
                    var t2 = await r2.text();
                    if (t2 && t2.length > 50 && (t2.indexOf('exam') !== -1 || t2.indexOf('考试') !== -1 || t2.indexOf('table') !== -1 || t2.indexOf('data') !== -1)) {
                      examData = t2;
                      break;
                    }
                  }
                } catch (e) {}
              }

              var gradeData = '';
              for (var k = 0; k < gradeUrls.length; k++) {
                try {
                  var gUrl = gradeUrls[k];
                  var gRes = await fetch(gUrl, {
                    credentials: 'include',
                    headers: {
                      'Accept': '*/*',
                      'X-Requested-With': 'XMLHttpRequest'
                    }
                  });
                  if (gRes.ok) {
                    var tG = await gRes.text();
                    if (tG && tG.length > 50 && (tG.indexOf('lnList') !== -1 || tG.indexOf('cjList') !== -1 || tG.indexOf('courseScore') !== -1 || tG.indexOf('table') !== -1)) {
                      gradeData = tG;
                      break;
                    }
                  }
                } catch (e) {}
              }

              var evalData = '';
              for (var ev = 0; ev < evalUrls.length; ev++) {
                try {
                  var evUrl = evalUrls[ev];
                  var isSearch = evUrl.indexOf('search') !== -1;
                  var evResp = await fetch(evUrl, {
                    method: isSearch ? 'POST' : 'GET',
                    headers: {
                      'Accept': 'application/json, text/javascript, */*; q=0.01',
                      'X-Requested-With': 'XMLHttpRequest'
                    },
                    credentials: 'include'
                  });
                  if (evResp.ok) {
                    var tEv = await evResp.text();
                    if (tEv && tEv.length > 30 && (tEv.indexOf('evaluationContent') !== -1 || tEv.indexOf('questionnaire') !== -1 || tEv.indexOf('data') !== -1)) {
                      evalData = tEv;
                      break;
                    }
                  }
                } catch (e) {}
              }

              return JSON.stringify({
                schedule: scheduleData,
                exam: examData,
                grade: gradeData,
                evaluation: evalData
              });
            })()
            ''',
          );

          var cleanJson = jsProbeResult.toString();
          if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
            cleanJson = jsonDecode(cleanJson) as String;
          }
          final dynamic parsedResult = jsonDecode(cleanJson);
          if (parsedResult is Map<String, dynamic>) {
            final rawSched = (parsedResult['schedule'] as String? ?? '').trim();
            if (rawSched.isNotEmpty) {
              final probedCourses = const TimetableParser().parse(rawSched);
              if (probedCourses.isNotEmpty) {
                HbuUrpGateway.setProbedCourses(probedCourses);
              }
            }

            final rawExam = (parsedResult['exam'] as String? ?? '').trim();
            if (rawExam.isNotEmpty) {
              final probedExams = const ExamParser().parse(rawExam);
              if (probedExams.isNotEmpty) {
                HbuUrpGateway.setProbedExams(probedExams);
              }
            }

            final rawGrade = (parsedResult['grade'] as String? ?? '').trim();
            if (rawGrade.isNotEmpty) {
              final probedGrades = const GradeParser().parse(rawGrade);
              if (probedGrades.isNotEmpty) {
                HbuUrpGateway.setProbedGrades(probedGrades);
              }
            }

            final rawEval = (parsedResult['evaluation'] as String? ?? '').trim();
            if (rawEval.isNotEmpty) {
              final probedEvals = const EvaluationParser().parseList(rawEval);
              if (probedEvals.isNotEmpty) {
                HbuUrpGateway.setProbedEvaluations(probedEvals);
              }
            }
          }
        } on Exception {
          // 同源嗅探异常不影响主登录流
        }
      }

      // 100% 已在教务系统内部，直接自动触发同步
      await _syncSessionAndComplete(probedUsername: probedName);
      return;
    }

    if (!isCasAuth) {
      // 检查 Cookie 是否包含会话标识
      final vpnUri = Uri.parse('https://v.hbu.cn/');
      final cookies = await _cookieManager.getCookies(domain: vpnUri);
      final hasSession = cookies.any((c) {
        final n = c.name.toLowerCase();
        return n.contains('wrdvpn') ||
            n.contains('webvpn') ||
            n.contains('wengine') ||
            n.contains('vpn') ||
            n.contains('ticket') ||
            n.contains('castgc') ||
            n.contains('session');
      });

      if (hasSession) {
        if (lowerUrl.contains('zhjw') ||
            lowerUrl.contains('eaff4b8b69386a45300b87')) {
          await _syncSessionAndComplete(
            cookies: cookies,
            probedUsername: probedName,
          );
        } else if (!lowerUrl.contains('/login')) {
          // 当前处于 WebVPN 门户（https://v.hbu.cn/），自动引导进入本科教务学生端
          if (mounted) {
            setState(() {
              _statusHint = 'WebVPN 连接成功，正在自动进入本科教务...';
            });
          }
          try {
            final clicked = await _controller?.runJavaScriptReturningResult('''
              (function() {
                var all = document.querySelectorAll('a, .el-card, div, span, p');
                for (var i = 0; i < all.length; i++) {
                  var t = (all[i].innerText || all[i].textContent || '').trim();
                  if (t === '本科教务学生端') {
                    var clickable = all[i].closest('a') || all[i].closest('.resource-item') || all[i].closest('.el-card') || all[i];
                    clickable.click();
                    return true;
                  }
                }
                return false;
              })()
            ''');
            final wasClicked = clicked == true || clicked.toString() == 'true';
            if (!wasClicked) {
              final zhjwUrl = WebVpnUrlRewriter.hbu().toWebVpn(
                Uri.parse('http://zhjw.hbu.cn/student/courseSelect/thisSemesterCurriculum/index'),
              );
              await _controller?.loadRequest(zhjwUrl);
            }
          } on Exception {
            final zhjwUrl = WebVpnUrlRewriter.hbu().toWebVpn(
              Uri.parse('http://zhjw.hbu.cn/student/courseSelect/thisSemesterCurriculum/index'),
            );
            await _controller?.loadRequest(zhjwUrl);
          }
        }
      }
    }
  }

  /// 提取 WebView Cookie 并桥接持久化至原生 CookieJar，更新会话状态。
  Future<void> _syncSessionAndComplete({
    List<WebViewCookie>? cookies,
    String? probedUsername,
  }) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _statusHint = '认证成功，正在同步教务会话...';
    });

    try {
      final cookieJar = ref.read(cookieJarProvider);
      final vpnUri = Uri.parse('https://v.hbu.cn/');
      final zhjwUri = Uri.parse('http://zhjw.hbu.cn/');

      final allCookies = cookies ?? await _cookieManager.getCookies(domain: vpnUri);

      // 若当前页面另有 URL，也一并补充采集 Cookie 并动态注册网关权威密文段
      Uri? activePageUri;
      if (_controller != null) {
        try {
          final curUrl = await _controller!.currentUrl();
          if (curUrl != null && curUrl.isNotEmpty) {
            final pageUri = Uri.parse(curUrl);
            activePageUri = pageUri;
            final pageCookies =
                await _cookieManager.getCookies(domain: pageUri);
            for (final pc in pageCookies) {
              if (!allCookies.any((c) => c.name == pc.name)) {
                allCookies.add(pc);
              }
            }

            // 动态捕获当前网关权威 Host Segment 并注册
            final seg = WebVpnUrlRewriter.extractSegment(pageUri);
            if (seg != null) {
              WebVpnUrlRewriter.registerValidatedSegment(
                'zhjw.hbu.cn',
                seg,
              );
            }
          }
        } on Exception {
          // 忽略二次补充查询异常
        }
      }

      final ioCookiesVpn = <io.Cookie>[];
      final ioCookiesZhjw = <io.Cookie>[];
      var nameFromCookie = '';

      for (final c in allCookies) {
        final cookieVpn = io.Cookie(c.name, c.value)
          ..domain = 'v.hbu.cn'
          ..path = '/';
        ioCookiesVpn.add(cookieVpn);

        final cookieZhjw = io.Cookie(c.name, c.value)
          ..domain = 'zhjw.hbu.cn'
          ..path = '/';
        ioCookiesZhjw.add(cookieZhjw);

        final lower = c.name.toLowerCase();
        if (lower == 'webvpn_user' ||
            lower == 'username' ||
            lower == 'user') {
          nameFromCookie = Uri.decodeComponent(c.value);
        }
      }

      if (ioCookiesVpn.isNotEmpty) {
        await cookieJar.saveFromResponse(vpnUri, ioCookiesVpn);
        await cookieJar.saveFromResponse(zhjwUri, ioCookiesZhjw);
        if (activePageUri != null && activePageUri.host.contains('hbu.cn')) {
          await cookieJar.saveFromResponse(activePageUri, ioCookiesVpn);
        }
      }

      final finalUsername = (probedUsername != null && probedUsername.isNotEmpty)
          ? probedUsername
          : (nameFromCookie.isNotEmpty
              ? nameFromCookie
              : (_detectedUsername ?? '河大学子'));

      // 启动免扰过渡保护期（防止返回主界面瞬时并发拉取网络波动误判）
      WebVpnInterceptor.markAuthenticatedNow();

      await ref.read(sessionControllerProvider.notifier).markAuthenticated(
            username: finalUsername,
          );

      // 触发数据重新拉取，确保主界面即刻呈现最新课表、成绩与考试
      await Future.wait([
        ref
            .read(timetableControllerProvider.notifier)
            .loadTimetable(forceRefresh: true),
        ref
            .read(gradesControllerProvider.notifier)
            .loadGrades(forceRefresh: true),
        ref.read(examControllerProvider.notifier).loadExams(forceRefresh: true),
        ref.read(evaluationControllerProvider.notifier).loadEvaluations(),
      ]);

      final probedCourseCount = HbuUrpGateway.cachedProbedCourses?.length ?? 0;
      final probedGradeCount = HbuUrpGateway.cachedProbedGrades?.length ?? 0;
      final probedExamCount = HbuUrpGateway.cachedProbedExams?.length ?? 0;
      var syncSummary = '教务会话已就绪';
      if (probedCourseCount > 0) {
        syncSummary = '已同步 $probedCourseCount 门课表';
        if (probedGradeCount > 0) {
          syncSummary += '、$probedGradeCount 门成绩';
        }
        if (probedExamCount > 0) {
          syncSummary += '、$probedExamCount 场考试';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('欢迎回来，$finalUsername！$syncSummary'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// 用户点击悬浮按钮手动强制触发会话同步
  Future<void> _manualSyncAndComplete() async {
    await _syncSessionAndComplete(probedUsername: _detectedUsername);
  }

  /// 刷新页面
  Future<void> _refresh() async {
    await _controller?.reload();
  }

  /// 清除 WebView Cookie 并重置到登录页
  Future<void> _resetCookies() async {
    await _cookieManager.clearCookies();
    await _controller?.loadRequest(Uri.parse(LoginPage.initialUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除 WebView 缓存与 Cookie')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: frostedFlexibleSpace(context),
        title: const Text('WebVPN 登录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新页面',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清除 Cookie 重置',
            onPressed: _resetCookies,
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                ),
              )
            : null,
      ),
      floatingActionButton: _controller != null
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _manualSyncAndComplete,
              icon: Icon(
                _isUrpDetected
                    ? Icons.check_circle_rounded
                    : Icons.login_rounded,
              ),
              label: Text(
                _isUrpDetected
                    ? '检测到教务主页，立即进入 App'
                    : '已进入教务系统？点击同步',
              ),
              backgroundColor: _isUrpDetected
                  ? scheme.primary
                  : scheme.secondaryContainer,
              foregroundColor: _isUrpDetected
                  ? scheme.onPrimary
                  : scheme.onSecondaryContainer,
            )
          : null,
      body: _controller != null
          ? Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_isSyncing)
                  ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(width: 16),
                              Text(_statusHint ?? '正在处理...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : _buildFallbackView(scheme),
    );
  }

  /// 当运行在不支持原生 WebView 平台时的兜底界面
  Widget _buildFallbackView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '当前环境未启用原生 WebView',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'WebVPN 登录依赖 Android 原生 WebView 进行官方统一认证并提取 Cookie。请在 Android 真机或模拟器上运行。',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                // 模拟开发环境调试快捷登录
                await ref
                    .read(sessionControllerProvider.notifier)
                    .markAuthenticated(username: '测试学号 20240101');
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('模拟登录完成（仅限测试环境）'),
            ),
          ],
        ),
      ),
    );
  }
}
