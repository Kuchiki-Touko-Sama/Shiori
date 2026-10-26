import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/shared/theme/app_theme.dart';
import 'package:shiori/shared/theme/theme_controller.dart';

/// 外观设置：主题模式、动态取色、OLED 纯黑、主题色。
class ThemeSettingsSection extends ConsumerWidget {
  const ThemeSettingsSection({super.key});

  Future<void> _showCustomColorDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final color = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义主题色'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '六位十六进制，如 2E7D32',
            prefixText: '#',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final input = controller.text.trim().replaceFirst('#', '');
              if (input.length != 6) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入 6 位十六进制颜色值')),
                );
                return;
              }
              final value = int.tryParse(input, radix: 16);
              if (value == null) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('颜色值格式不正确')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(Color(0xFF000000 | value));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (color != null) {
      await ref
          .read(themeControllerProvider.notifier)
          .setSeedColor(color);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final notifier = ref.read(themeControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '外观',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('跟随系统'),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
              ],
              selected: {settings.mode},
              onSelectionChanged: (selection) =>
                  notifier.setMode(selection.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Material You 动态取色'),
              subtitle: const Text('跟随系统壁纸配色（Android 12+）'),
              value: settings.useDynamicColor,
              onChanged: (value) =>
                  notifier.setUseDynamicColor(value: value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('OLED 纯黑背景'),
              subtitle: const Text('深色模式下使用纯黑背景，省电'),
              value: settings.oledDark,
              onChanged: (value) => notifier.setOledDark(value: value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('主题色'),
              subtitle: const Text('默认为绿色'),
              trailing: Wrap(
                spacing: 8,
                runAlignment: WrapAlignment.center,
                children: [
                  for (final color in kSeedColorPresets)
                    _ColorDot(
                      color: color,
                      selected: settings.seedColor.toARGB32() ==
                          color.toARGB32(),
                      onTap: () => notifier.setSeedColor(color),
                    ),
                  _ColorDot.custom(
                    onTap: () => _showCustomColorDialog(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.onTap,
    this.selected = false,
  }) : icon = null;

  const _ColorDot.custom({required this.onTap})
      : color = null,
        icon = Icons.edit,
        selected = false;

  final Color? color;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: color ?? scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(
            icon ?? (selected ? Icons.check : null),
            size: 16,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
