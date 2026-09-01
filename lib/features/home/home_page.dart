import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_card.dart';

/// 首页：工具总览网格。
///
/// 展示应用简介与全部工具卡片，点击工具由 [onToolTap] 回调决定
/// 是切换桌面内容区还是压入移动端路由。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onToolTap});

  final ValueChanged<ToolInfo> onToolTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = Responsive.isDesktop(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: isDesktop ? 28 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, colorScheme, isDesktop),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.gridColumns(context),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isDesktop ? 1.25 : 1.05,
                ),
                itemCount: ToolRegistry.tools.length,
                itemBuilder: (context, index) {
                  final tool = ToolRegistry.tools[index];
                  return ToolCard(tool: tool, onTap: () => onToolTap(tool));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.appSlogan,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (isDesktop)
          Chip(
            avatar: Icon(Icons.verified_rounded, size: 16, color: colorScheme.primary),
            label: const Text('跨端自适应 · Flutter'),
            labelStyle: theme.textTheme.labelMedium,
            side: BorderSide.none,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }
}
