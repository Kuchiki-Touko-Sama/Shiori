import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shiori/core/session/session_manager.dart';
import 'package:shiori/core/updater/update_checker.dart';
import 'package:shiori/features/settings/widgets/theme_settings_section.dart';
import 'package:shiori/shared/widgets/frosted_app_bar.dart';

/// 「我的」页：账号入口、网络模式、外观设置、关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: frostedFlexibleSpace(context),
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _AccountCard(session: session),
          const SizedBox(height: 8),
          const _AcademicToolsCard(),
          const SizedBox(height: 8),
          _NetworkSettingsCard(session: session),
          const SizedBox(height: 8),
          const ThemeSettingsSection(),
          const SizedBox(height: 8),
          const _AboutSection(),
        ],
      ),
    );
  }
}

class _AcademicToolsCard extends StatelessWidget {
  const _AcademicToolsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '教务功能',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.primary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('教学质量评价'),
            subtitle: const Text('期末一键好评与问卷提交'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/evaluation'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.session});

  final SessionState session;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？已缓存的数据仍可在本地查看。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(sessionControllerProvider.notifier).logout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出登录')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (session.isAuthenticated) {
      final loginTimeStr = session.lastLoginTime != null
          ? DateFormat('MM-dd HH:mm').format(session.lastLoginTime!)
          : '刚刚';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.school),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.username ?? '已登录',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '会话有效 · $loginTimeStr 登录',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _confirmLogout(context, ref),
                child: const Text('退出'),
              ),
            ],
          ),
        ),
      );
    }

    if (session.status == AuthStatus.expired) {
      return Card(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                child: const Icon(Icons.warning_amber_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.username ?? '用户'}（会话已过期）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '请重新登录以同步最新课表与成绩',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.push('/login'),
                child: const Text('重登'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              child: const Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '未登录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '登录后同步课表、成绩与考试安排',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context.push('/login'),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkSettingsCard extends ConsumerWidget {
  const _NetworkSettingsCard({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '网络访问链路',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '校外请选择 WebVPN 隧道访问；若连接了 HBU 校园 Wi-Fi，可选择直连模式降低延迟。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<NetworkMode>(
                segments: const [
                  ButtonSegment(
                    value: NetworkMode.webVpn,
                    label: Text('校外 WebVPN'),
                    icon: Icon(Icons.vpn_lock_outlined),
                  ),
                  ButtonSegment(
                    value: NetworkMode.direct,
                    label: Text('校园网直连'),
                    icon: Icon(Icons.wifi),
                  ),
                ],
                selected: {session.networkMode},
                onSelectionChanged: (selected) {
                  unawaited(
                    ref
                        .read(sessionControllerProvider.notifier)
                        .setNetworkMode(selected.first),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context)
      ..showSnackBar(
        const SnackBar(
          content: Text('正在检查 GitHub 最新版本...'),
          duration: Duration(seconds: 1),
        ),
      );

    final info = await ref.read(updateCheckerProvider).check();
    if (!context.mounted) return;

    if (info.hasUpdate) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('发现新版本 v${info.latestVersion}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本: v${info.currentVersion}'),
              const SizedBox(height: 8),
              const Text('更新日志:'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(info.releaseNotes),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('前往更新'),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('已是最新版本 (v${info.currentVersion})')),
      );
    }
  }

  Future<void> _showDisclaimer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私与免责声明'),
        content: const Text(
          'Shiori 是河北大学教务系统的第三方开源客户端，仅供学习交流使用。\n\n'
          '· 所有数据均来自学校教务系统，且只保存在你的手机本地，开发者不收集、不上传任何数据；\n'
          '· 登录凭据（如选择保存）经 Android Keystore 加密存储；\n'
          '· 请勿将本应用用于抢课等高频请求操作，使用产生的一切后果由使用者自行承担。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            trailing: const Text('v1.0.0+1'),
            onTap: () => _checkUpdate(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt_rounded),
            title: const Text('检查更新'),
            subtitle: const Text('通过 GitHub Releases 获取最新版'),
            onTap: () => _checkUpdate(context, ref),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('开源地址'),
            subtitle: Text('GitHub 仓库（Predidit/Shiori）'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私与免责声明'),
            onTap: () => _showDisclaimer(context),
          ),
        ],
      ),
    );
  }
}
