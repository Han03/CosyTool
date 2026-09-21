import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/tool_card.dart';

/// 工具分组定义（首页信息架构）：显式工具 ID 白名单，保证每工具只归一组。
class _ToolGroup {
  const _ToolGroup(this.title, this.icon, this.ids);

  final String title;
  final IconData icon;
  final Set<String> ids;

  bool contains(ToolInfo t) => ids.contains(t.id);
}

const List<_ToolGroup> _groups = [
  _ToolGroup('音频', Icons.graphic_eq_rounded, {'recorder', 'decibel', 'ear_monitor'}),
  _ToolGroup('计时', Icons.timer_rounded, {'stopwatch', 'countdown', 'pomodoro', 'camera_timer'}),
  _ToolGroup('文本', Icons.text_fields_rounded, {'text_tools', 'word_count', 'text_reader'}),
  _ToolGroup(
    '日常工具',
    Icons.handyman_rounded,
    {'dice', 'random_number', 'converter', 'flashlight', 'qrcode'},
  ),
  _ToolGroup('存储与设置', Icons.storage_rounded, {'settings'}),
  _ToolGroup('关于', Icons.info_rounded, {'about'}),
];

/// 首页：工具总览（分组 + 桌面搜索）。
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onToolTap, this.searchFocusNode});

  final ValueChanged<ToolInfo> onToolTap;

  /// 外部注入的搜索框焦点（桌面快捷键 Ctrl+F 使用）；为空时内部创建。
  final FocusNode? searchFocusNode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _searchFocus = widget.searchFocusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.searchFocusNode == null) _searchFocus.dispose();
    super.dispose();
  }

  List<_ToolGroup> get _visibleGroups {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _groups;
    return [
      _ToolGroup('搜索结果', Icons.search_rounded, {
        for (final t in ToolRegistry.tools)
          if (t.name.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q) ||
              t.tags.any((tag) => tag.toLowerCase().contains(q)))
            t.id,
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = Responsive.isDesktop(context);
    final groups = _visibleGroups;
    final showGroups = _query.trim().isEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xl : AppSpacing.md,
        vertical: isDesktop ? 28 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, colorScheme, isDesktop),
              if (isDesktop) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildSearchBar(theme, colorScheme),
              ],
              for (final group in groups) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildGroupTitle(theme, colorScheme, group),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                _buildGrid(theme, colorScheme, group, isDesktop, showGroups),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(
    ThemeData theme,
    ColorScheme colorScheme,
    _ToolGroup group,
    bool isDesktop,
    bool showGroups,
  ) {
    final tools = showGroups
        ? ToolRegistry.tools.where(group.contains).toList()
        : ToolRegistry.tools.where(group.contains).toList();
    if (tools.isEmpty) {
      return EmptyState(
        compact: true,
        icon: Icons.search_off_rounded,
        title: '没有匹配的工具',
        message: '换个关键词试试，或清空搜索',
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: isDesktop ? 1.35 : 1.1,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return ToolCard(
          tool: tool,
          onTap: () => widget.onToolTap(tool),
        );
      },
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
            avatar: Icon(Icons.verified_rounded, size: 16, color: BrandColors.primary),
            label: const Text('跨端自适应 · Flutter'),
            labelStyle: theme.textTheme.labelMedium,
            side: BorderSide.none,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colorScheme) {
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: '搜索工具（如：录音、文本、计时）…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
        isDense: true,
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, ColorScheme colorScheme, _ToolGroup group) {
    return Row(
      children: [
        Icon(group.icon, size: 16, color: BrandColors.primary),
        const SizedBox(width: 6),
        Text(
          group.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
