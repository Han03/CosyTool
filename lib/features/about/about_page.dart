import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/platform_check.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 关于页面：项目介绍、技术栈与平台支持。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static final ToolInfo _tool = ToolRegistry.of('about');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = Responsive.isDesktop(context);

    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + 名称
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [BrandColors.primary, BrandColors.secondary],
                          ),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'v${AppConstants.version}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CosyTool 是一个基于 Flutter 的跨平台轻量工具箱，'
                    '把日常高频的小工具集中在一个清爽的应用里。'
                    '项目采用响应式布局，同一套代码在手机、平板和桌面端都能获得良好的体验。',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle(theme, '技术栈'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Tag('Flutter 3.x'),
                      _Tag('Dart 3.x'),
                      _Tag('Material 3'),
                      _Tag('record'),
                      _Tag('audioplayers'),
                      _Tag('camera'),
                      _Tag('permission_handler'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle(theme, '平台支持'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag('Android'),
                      _Tag('iOS'),
                      _Tag('Windows'),
                      _Tag('macOS'),
                      _Tag('Linux'),
                      _Tag('Web'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前运行平台：${PlatformCheck.platformLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 28),
                  _sectionTitle(theme, '项目地址'),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.link_rounded),
                      title: const Text('github.com/Han03/CosyTool'),
                      subtitle: const Text('源码仓库 · 欢迎 Star'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在浏览器中打开 github.com/Han03/CosyTool')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
