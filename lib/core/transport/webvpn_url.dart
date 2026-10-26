import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 网瑞达（WRD）WebVPN 加密 URL 改写器。
///
/// WebVPN 网关把内网原始地址改写为如下形态：
///
/// ```text
/// https://{webvpnHost}/{scheme}[-{port}]/{ivHex}{hostCipherHex}/{原始路径}
/// ```
///
/// 密文段由两部分拼接：前 32 个十六进制字符是本次加密使用的 IV，
/// 其后是内网域名经 AES-128-CFB（无填充、小写十六进制）加密的密文。
/// 算法依据开源逆向项目 webvpn-dlut / Get-Web-Address，抓包确认
/// 密钥配对后即可投入使用（见 docs/protocol.md）。
class WebVpnUrlRewriter {
  WebVpnUrlRewriter({
    required this.webvpnHost,
    required this.key,
    required this.iv,
  })  : assert(
          utf8.encode(key).length == 16,
          'AES-128 密钥必须为 16 字节',
        ),
        assert(
          utf8.encode(iv).length == 16,
          'CFB IV 必须为 16 字节',
        );

  /// 河北大学默认改写器。
  ///
  /// 密钥配对已于 2026 年抓包与网关前端源码核实：
  /// var __vpn_host_crypt_key = "wrdvpnisthebest!";
  /// var __vpn_host_crypt_iv = "wrdvpnisthebest!";
  factory WebVpnUrlRewriter.hbu() => WebVpnUrlRewriter(
        webvpnHost: hbuWebVpnHost,
        key: legacyKeyIv,
        iv: legacyKeyIv,
      );

  /// WebVPN 网关域名，如 `v.hbu.cn`。
  final String webvpnHost;

  /// AES-128 密钥。网关升级会更换密钥，以抓包结果为准。
  final String key;

  /// CFB 模式 IV，以十六进制明文形式出现在每个改写 URL 的密文段前。
  final String iv;

  /// 早期网关密钥对（key 与 iv 相同）。
  static const String legacyKeyIv = 'wrdvpnisthebest!';

  /// 2023 年之后的密钥对（key 与 iv 相同）。
  static const String currentKeyIv = r'Wxzxvpn2023key@$';

  /// 河北大学 WebVPN 网关。
  static const String hbuWebVpnHost = 'v.hbu.cn';

  /// 真实网关验证过的主机密文段缓存映射（如 'zhjw.hbu.cn' -> '777264...'）。
  static final Map<String, String> _validatedHostSegments = <String, String>{};

  /// 注册权威主机密文段（例如从真机 WebView URL 中动态提取）。
  static void registerValidatedSegment(String host, String segment) {
    if (segment.isNotEmpty) {
      _validatedHostSegments[host.toLowerCase()] = segment;
    }
  }

  /// 获取已注册的主机密文段。
  static String? getValidatedSegment(String host) =>
      _validatedHostSegments[host.toLowerCase()];

  /// 清除缓存（仅用于测试或登出重置）。
  static void clearValidatedSegments() {
    _validatedHostSegments.clear();
  }

  /// 尝试从 WebVPN URL 中提取密文段（形如 /http/777264.../ 或 /https/777264.../）。
  static String? extractSegment(Uri uri) {
    if (uri.pathSegments.length >= 2) {
      final schemePart = uri.pathSegments[0];
      if (schemePart.startsWith('http')) {
        final seg = uri.pathSegments[1];
        if (seg.length > 32) {
          return seg;
        }
      }
    }
    return null;
  }

  static const int _blockSize = 16;

  late final Uint8List _keyBytes = Uint8List.fromList(utf8.encode(key));
  late final AESEngine _aes = AESEngine()
    ..init(
      true,
      KeyParameter(_keyBytes),
    );

  /// 把原始教务地址改写为通过 WebVPN 访问的地址。
  Uri toWebVpn(Uri url) {
    final scheme = url.scheme;
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError.value(url, 'url', '仅支持 http/https 地址');
    }
    // Uri 不记录端口是否显式写出，按 scheme 默认端口判断
    final defaultPort = scheme == 'https' ? 443 : 80;
    final portPart = url.port == defaultPort ? '' : '-${url.port}';

    // 优先采用从真机 WebView 动态捕获并校验过的权威密文段
    final knownSegment = _validatedHostSegments[url.host.toLowerCase()];
    final String segment;
    if (knownSegment != null && knownSegment.isNotEmpty) {
      segment = knownSegment;
    } else {
      final cipherHex = _toHex(
        _cfb128(
          Uint8List.fromList(utf8.encode(url.host)),
          forEncryption: true,
          ivOverride: null,
        ),
      );
      segment = '${_toHex(utf8.encode(iv))}$cipherHex';
    }

    final path = url.path.startsWith('/') ? url.path : '/${url.path}';
    final target =
        'https://$webvpnHost/$scheme$portPart/$segment$path';
    return url.hasQuery
        ? Uri.parse('$target?${url.query}')
        : Uri.parse(target);
  }

  /// 把 WebVPN 改写地址还原为原始教务地址。
  Uri toOrdinary(Uri webvpnUrl) {
    final segments = webvpnUrl.pathSegments;
    if (segments.length < 2) {
      throw const FormatException('不是合法的 WebVPN 改写地址：缺少密文段');
    }
    final match =
        RegExp(r'^(https?)(?:-(\d+))?$').firstMatch(segments[0]);
    if (match == null) {
      throw const FormatException('无法解析 WebVPN 协议段');
    }
    final scheme = match.group(1)!;
    final port = int.tryParse(match.group(2) ?? '') ?? 0;
    final host = _hostFromSegment(segments[1]);
    final restPath = segments
        .skip(2)
        .map(Uri.decodeComponent)
        .join('/');
    final portPart = port == 0 ? '' : ':$port';
    final target = '$scheme://$host$portPart/$restPath';
    return webvpnUrl.hasQuery
        ? Uri.parse('$target?${webvpnUrl.query}')
        : Uri.parse(target);
  }

  String _hostFromSegment(String segment) {
    if (segment.length <= 32 || segment.length.isOdd) {
      throw const FormatException('密文段长度不合法');
    }
    final ivBytes = _fromHex(segment.substring(0, 32));
    final cipherBytes = _fromHex(segment.substring(32));
    final plain = _cfb128(
      cipherBytes,
      forEncryption: false,
      ivOverride: ivBytes,
    );
    return utf8.decode(plain);
  }

  /// AES-128-CFB（128-bit 反馈，等价 PyCryptodome segment_size=128）。
  ///
  /// CFB 是流式模式，最后一块允许不足 16 字节；反馈寄存器永远保存
  /// 最近 16 字节密文，加密时密文是输出块，解密时密文是输入块。
  Uint8List _cfb128(
    Uint8List data, {
    required bool forEncryption,
    required Uint8List? ivOverride,
  }) {
    final register = Uint8List.fromList(
      ivOverride ?? utf8.encode(iv),
    );
    final out = BytesBuilder(copy: false);
    final keystream = Uint8List(_blockSize);
    for (var offset = 0; offset < data.length; offset += _blockSize) {
      _aes.processBlock(register, 0, keystream, 0);
      final chunkLength = math.min(_blockSize, data.length - offset);
      final chunk = Uint8List(chunkLength);
      for (var i = 0; i < chunkLength; i++) {
        chunk[i] = data[offset + i] ^ keystream[i];
      }
      if (offset + chunkLength < data.length) {
        final feedback = forEncryption
            ? chunk
            : Uint8List.sublistView(
                data,
                offset,
                offset + chunkLength,
              );
        register.setRange(0, _blockSize, feedback);
      }
      out.add(chunk);
    }
    return out.toBytes();
  }

  String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Uint8List _fromHex(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final value = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (value == null) {
        throw const FormatException('密文段包含非十六进制字符');
      }
      bytes.add(value);
    }
    return Uint8List.fromList(bytes);
  }
}
