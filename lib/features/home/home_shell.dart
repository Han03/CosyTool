import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/app_logo.dart';
import 'home_page.dart';

/// 响应式应用外壳。
///
/// - 桌面 / 平板：左侧固定导航栏 + 右侧内容区，点击导航切换内容
/// - 手机：首页网格 + 抽屉导航，工具以全屏页面压入
///
/// 工具数量较多（12+），桌面侧采用可滚动的自定义侧边栏，
/// 避免 NavigationRail 在矮屏上溢出。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// 导航条目：首位为首页（null），其后依次为工具与关于页。
  List<ToolInfo?> get _navTools => <ToolInfo?>[
    null,
    ...ToolRegistry.tools,
    ToolRegistry.aboutTools.first,
  ];

  void _selectIndex(int index) => setState(() => _selectedIndex = index);

  void _openTool(BuildContext context, ToolInfo tool) {
    if (Responsive.isDesktop(context) || Responsive.isTablet(context)) {
      final index = _navTools.indexOf(tool);
      if (index >= 0) {
        _selectIndex(index);
      }
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => tool.builder(context)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = Responsive.of(context);
    if (type == ScreenType.desktop || type == ScreenType.tablet) {
      return _buildSidebarLayout(context);
    }
    return _buildMobileLayout(context);
  }

  // ---------------- 桌面 / 平板 ----------------

  Widget _buildSidebarLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            navTools: _navTools,
            onSelected: _selectIndex,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildPane(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPane(BuildContext context) {
    final tool = _navTools[_selectedIndex];
    if (tool == null) {
      return HomePage(
        key: const ValueKey('pane-home'),
        onToolTap: (t) => _openTool(context, t),
      );
    }
    return KeyedSubtree(
      key: ValueKey('pane-${tool.id}'),
      child: tool.builder(context),
    );
  }

  // ---------------- 手机 ----------------

  Widget _buildMobileLayout(BuildContext context) {
    final about = ToolRegistry.aboutTools.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        actions: [
          IconButton(
            tooltip: '关于',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _openTool(context, about),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: HomePage(onToolTap: (t) => _openTool(context, t)),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppThemeSeed.primary, AppThemeSeed.secondary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppConstants.appSlogan,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _navTools.length; i++) _drawerTile(context, i),
          const Divider(),
          _buildAppearanceSection(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v${AppConstants.version} · ${colorScheme.outline}',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  /// 外观设置：跟随系统 / 浅色 / 深色，实时生效并持久化。
  Widget _buildAppearanceSection(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeController,
      builder: (context, mode, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.settings_brightness_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '外观',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('跟随系统'),
                      icon: Icon(Icons.brightness_auto_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode_rounded, size: 16),
                    ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    widget.themeController.setMode(s.first);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _drawerTile(BuildContext context, int index) {
    final tool = _navTools[index];
    return ListTile(
      leading: Icon(tool?.icon ?? Icons.home_rounded),
      title: Text(tool?.name ?? '首页'),
      dense: true,
      onTap: () {
        Navigator.of(context).pop();
        if (tool == null) return;
        _openTool(context, tool);
      },
    );
  }
}

/// 桌面端左侧导航栏。
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.navTools,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<ToolInfo?> navTools;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = Responsive.isTablet(context) ? 210.0 : 236.0;

    return SizedBox(
      width: width,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        child: Column(
          children: [
            // 品牌区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  const AppLogo(size: 40, iconSize: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'v${AppConstants.version}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 导航列表（可滚动）
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: navTools.length,
                itemBuilder: (context, index) {
                  final tool = navTools[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        // 选中指示条（品牌绿）
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 3,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppThemeSeed.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            selected: selected,
                            selectedTileColor: colorScheme.primaryContainer
                                .withValues(alpha: 0.55),
                            leading: Icon(
                              tool?.icon ?? Icons.home_rounded,
                              size: 20,
                              color: selected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              tool?.name ?? '首页',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                              ),
                            ),
                            onTap: () => onSelected(index),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 底部说明
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${ToolRegistry.tools.length} 款常用工具',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
