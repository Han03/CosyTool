import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/tool_info.dart';
import 'hover_card.dart';

/// 首页工具卡片。
///
/// 统一品牌绿渐变图标块（主色调收敛），桌面端悬停抬升 + 点击波纹。
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.tool,
    this.onTap,
  });

  final ToolInfo tool;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BrandColors.primary, BrandColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: BrandColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(tool.icon, color: Colors.white, size: 25),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  tool.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (tool.mobileOnly)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: '仅移动端可用',
                    child: Icon(
                      Icons.phone_android_rounded,
                      size: 14,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              tool.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
