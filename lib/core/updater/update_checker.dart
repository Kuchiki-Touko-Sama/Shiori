import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/network/dio_client.dart';

/// 版本更新信息
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.downloadUrl,
    this.publishedAt,
  });

  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
  final String? publishedAt;
}

/// GitHub Releases 版本检查服务
class UpdateChecker {
  const UpdateChecker({
    required this.dio,
    this.currentVersion = '1.0.0',
    this.repoOwner = 'Predidit',
    this.repoName = 'Shiori',
  });

  final Dio dio;
  final String currentVersion;
  final String repoOwner;
  final String repoName;

  /// 检查 GitHub Releases 最新版本
  Future<UpdateInfo> check() async {
    final url =
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

    try {
      final response = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      final data = response.data;
      if (data != null) {
        final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
        final body = data['body'] as String? ?? '暂无更新日志';
        final publishedAt = data['published_at'] as String?;

        String? apkDownloadUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                apkDownloadUrl = asset['browser_download_url'] as String?;
                break;
              }
            }
          }
          if (apkDownloadUrl == null && assets.first is Map<String, dynamic>) {
            apkDownloadUrl = (assets.first
                as Map<String, dynamic>)['browser_download_url'] as String?;
          }
        }
        apkDownloadUrl ??= data['html_url'] as String?;

        final hasUpdate = _compareVersion(tagName, currentVersion) > 0;

        return UpdateInfo(
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          latestVersion: tagName.isNotEmpty ? tagName : currentVersion,
          releaseNotes: body,
          downloadUrl: apkDownloadUrl,
          publishedAt: publishedAt,
        );
      }
    } on Exception catch (_) {
      // 网络请求失败、无网络或 GitHub API 404/限流时友好返回当前无更新
    }

    return UpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseNotes: '当前已是最新版本',
    );
  }

  /// 比较两个三段式 semver 版本号（如 1.0.1 > 1.0.0）
  static int _compareVersion(String v1, String v2) {
    final p1 = v1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final p2 = v2.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < maxLen; i++) {
      final num1 = i < p1.length ? p1[i] : 0;
      final num2 = i < p2.length ? p2[i] : 0;
      if (num1 > num2) return 1;
      if (num1 < num2) return -1;
    }
    return 0;
  }
}

/// UpdateChecker Provider
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final dio = ref.watch(dioClientProvider);
  return UpdateChecker(dio: dio);
});
