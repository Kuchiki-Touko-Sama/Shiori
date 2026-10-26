import 'dart:ui';
import 'package:flutter/material.dart';

/// 生成微透毛玻璃背景组件，用于各类 AppBar 的 flexibleSpace。
///
/// 具备轻微高斯模糊与半透明表面色，边缘带极细微描边，呈现现代质感。
Widget frostedFlexibleSpace(
  BuildContext context, {
  double blur = 12.0,
  double alphaLight = 0.85,
  double alphaDark = 0.80,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final surfaceColor = theme.colorScheme.surface;

  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor.withValues(
            alpha: isDark ? alphaDark : alphaLight,
          ),
          border: Border(
            bottom: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
              width: 0.5,
            ),
          ),
        ),
      ),
    ),
  );
}
