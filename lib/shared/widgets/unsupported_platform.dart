import 'package:flutter/material.dart';

/// 不支持当前平台时的占位视图。
///
/// 例如相机、手电筒等硬件依赖型工具在桌面端不可用，
/// 统一用该组件给出友好提示，而不是直接报错。
class UnsupportedPlatformView extends StatelessWidget {
  const UnsupportedPlatformView({
    super.key,
    required this.toolName,
    required this.icon,
  });

  final String toolName;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: colorScheme.outline),
              ),
              const SizedBox(height: 24),
              Text(
                '“$toolName”需要移动端硬件支持',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '当前设备为桌面端，无法调用相机 / 手电筒等硬件。\n请在 Android 或 iOS 设备上运行体验此工具。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
