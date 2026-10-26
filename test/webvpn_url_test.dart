import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/transport/webvpn_url.dart';

void main() {
  group('WebVpnUrlRewriter 已知答案（与 PyCryptodome 交叉验证）', () {
    // key = Wxzxvpn2023key@$ / iv = wrdvpnisthebest!
    final rewriter = WebVpnUrlRewriter(
      webvpnHost: 'v.hbu.cn',
      key: WebVpnUrlRewriter.currentKeyIv,
      iv: WebVpnUrlRewriter.legacyKeyIv,
    );

    test('域名 jwxt.hbu.edu.cn 的密文段', () {
      final url = rewriter.toWebVpn(
        Uri.parse('http://jwxt.hbu.edu.cn/xkAction.do?actionType=6'),
      );
      expect(
        url.pathSegments[1],
        '77726476706e697374686562657374210af02d925df638a723522339ab0c9e',
      );
    });

    test('域名 urp.hbu.edu.cn 的密文段', () {
      final url = rewriter.toWebVpn(
        Uri.parse('https://urp.hbu.edu.cn/'),
      );
      expect(
        url.pathSegments[1],
        '77726476706e6973746865626573742115f525c81bfc2ffc68533262e601',
      );
    });

    test('域名 202.206.1.10 的密文段', () {
      final url = rewriter.toWebVpn(
        Uri.parse('http://202.206.1.10:8080/index.jsp'),
      );
      expect(
        url.pathSegments[1],
        '77726476706e6973746865626573742152b767c841ae6cfc3c19767c',
      );
      expect(url.pathSegments[0], 'http-8080');
    });

    test('河北大学综合教务 zhjw.hbu.cn 真实网关密文段验证', () {
      final hbuRewriter = WebVpnUrlRewriter.hbu();
      final url = hbuRewriter.toWebVpn(
        Uri.parse('http://zhjw.hbu.cn/student/courseSelect/calendarSchedule/index'),
      );
      expect(
        url.pathSegments[1],
        '77726476706e69737468656265737421eaff4b8b69386a45300b87',
      );
    });
  });

  group('真实世界 URL 前缀结构', () {
    test('legacy IV 的前缀与公开观测的网瑞达 URL 一致', () {
      final rewriter = WebVpnUrlRewriter(
        webvpnHost: 'v.hbu.cn',
        key: WebVpnUrlRewriter.currentKeyIv,
        iv: WebVpnUrlRewriter.legacyKeyIv,
      );
      final url = rewriter.toWebVpn(Uri.parse('http://jwxt.hbu.edu.cn/'));
      expect(
        url.pathSegments[1].startsWith('77726476706e69737468656265737421'),
        isTrue,
        reason: '真实高校 WebVPN URL 均以该前缀（hex of '
            '"wrdvpnisthebest!"）开头',
      );
    });
  });

  group(r'key = iv = Wxzxvpn2023key@$ 配对（大连理工大学当前配对）', () {
    test('域名 portal.dlut.edu.cn 的密文段', () {
      final rewriter = WebVpnUrlRewriter(
        webvpnHost: 'webvpn.dlut.edu.cn',
        key: WebVpnUrlRewriter.currentKeyIv,
        iv: WebVpnUrlRewriter.currentKeyIv,
      );
      final url = rewriter.toWebVpn(
        Uri.parse('https://portal.dlut.edu.cn/'),
      );
      expect(
        url.pathSegments[1],
        '57787a7876706e323032336b657940246817100cfd0fdd4aa659ee7694bf9069de28',
      );
    });
  });

  group('往返转换', () {
    final rewriter = WebVpnUrlRewriter.hbu();

    final cases = <Uri>[
      Uri.parse('http://jwxt.hbu.edu.cn/xkAction.do?actionType=6'),
      Uri.parse('https://urp.hbu.edu.cn/student/integratedQuery/'
          'scoreQuery/allTermScores/index'),
      Uri.parse('http://202.206.1.10:8080/login.jsp'),
      Uri.parse('https://jwc.hbu.edu.cn/index/zhjwxt.htm'),
    ];

    for (final original in cases) {
      test('$original 往返一致', () {
        final webvpn = rewriter.toWebVpn(original);
        expect(webvpn.host, 'v.hbu.cn');
        expect(webvpn.scheme, 'https');
        final restored = rewriter.toOrdinary(webvpn);
        expect(restored.host, original.host);
        expect(restored.scheme, original.scheme);
        expect(restored.path, original.path);
        expect(restored.query, original.query);
        expect(restored.port, original.port);
      });
    }
  });

  group('异常处理', () {
    final rewriter = WebVpnUrlRewriter.hbu();

    test('非 http/https 协议抛出 ArgumentError', () {
      expect(
        () => rewriter.toWebVpn(Uri.parse('ftp://jwxt.hbu.edu.cn/')),
        throwsArgumentError,
      );
    });

    test('缺少密文段的地址抛出 FormatException', () {
      expect(
        () => rewriter.toOrdinary(Uri.parse('https://v.hbu.cn/login')),
        throwsFormatException,
      );
    });
  });
}
