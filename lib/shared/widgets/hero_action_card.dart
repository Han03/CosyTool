import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Hero 操作区：每个工具页的视觉焦点。
///
/// 中央大操作圆钮（或大按钮）+ 状态标题 + 副文案 + 可选 loading，
/// 主操作在页面内优先被看到。
class HeroActionCard extends StatelessWidget {
  const HeroActionCard({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.active = false,
    this.loading = false,
    this.activeColor,
    this.buttonSize = 132,
    this.trailing,
    this.backgroundColor,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final bool loading;
  final Color? activeColor;
  final double buttonSize;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = active
        ? (activeColor ?? BrandColors.primary)
        : colorScheme.surfaceContainerHighest;
    final fg = active ? Colors.white : colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      color: backgroundColor ?? colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            // 呼吸光环：激活时外圈柔光
            AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.easeOut,
              padding: EdgeInsets.all(active ? 8 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: loading ? null : onTap,
                  child: SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(icon, size: buttonSize * 0.4, color: fg),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? accent : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(height: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
