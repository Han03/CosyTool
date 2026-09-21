import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/running_sessions_bar.dart';
import 'command_palette.dart';
import 'home_page.dart';

/// 响应式应用外壳。
///
/// - 桌面 / 平板：左侧固定导航栏 + 右侧内容区
/// - 手机：首页网格 + 抽屉导航
///
/// 侧栏只保留骨架入口（首页 / 设置 / 关于），工具一律在首页
/// 搜索 / 命令面板（Ctrl+K）中打开，避免与首页内容重复。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// 侧栏选中项：0=首页 1=设置 2=关于。
  int _selectedIndex = 0;

  /// 当前内容区打开的工具（null 时显示侧栏项内容）。
  ToolInfo? _currentTool;

  /// 首页搜索框焦点（桌面 Ctrl+F 注入）。
  final FocusNode _searchFocus = FocusNode();

  /// 侧栏条目：首页（null）→ 设置 → 关于。
  List<ToolInfo?> get _sidebarTools => <ToolInfo?>[
    null,
    ToolRegistry.of('settings'),
    ToolRegistry.aboutTools.first,
  ];

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _selectSidebar(int index) {
    setState(() {
      _selectedIndex = index;
      _currentTool = null;
    });
  }

  /// 打开工具：设置 / 关于切换侧栏项，普通工具直接在内容区显示。
  void _openTool(BuildContext context, ToolInfo tool) {
    if (Responsive.isDesktop(context) || Responsive.isTablet(context)) {
      setState(() {
        if (tool.id == 'settings') {
          _selectedIndex = 1;
          _currentTool = null;
        } else if (tool.id == 'about') {
          _selectedIndex = 2;
          _currentTool = null;
        } else {
          _currentTool = tool;
        }
      });
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => tool.builder(context)));
    }
  }

  /// 桌面快捷键：Ctrl+F 聚焦首页搜索、Ctrl+, 打开设置、Ctrl+K 命令面板。
  Widget _withShortcuts(BuildContext context, Widget child) {
    final isDesktop =
        Responsive.isDesktop(context) || Responsive.isTablet(context);
    if (!isDesktop) return child;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (_selectedIndex != 0 || _currentTool != null) {
            _selectSidebar(0);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _searchFocus.requestFocus();
          });
        },
        const SingleActivator(
          LogicalKeyboardKey.comma,
          control: true,
        ): () {
          _selectSidebar(1);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          showCommandPalette(
            context,
            onSelected: (t) => _openTool(context, t),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = Responsive.of(context);
    final shell = type == ScreenType.desktop || type == ScreenType.tablet
        ? _buildSidebarLayout(context)
        : _buildMobileLayout(context);
    return _withShortcuts(context, shell);
  }

  // ---------------- 桌面 / 平板 ----------------

  Widget _buildSidebarLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            sidebarTools: _sidebarTools,
            onSelected: _selectSidebar,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                RunningSessionsBar(onOpenTool: (id) => _openToolById(context, id)),
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
          ),
        ],
      ),
    );
  }

  void _openToolById(BuildContext context, String toolId) {
    final tool = ToolRegistry.of(toolId);
    _openTool(context, tool);
  }

  Widget _buildPane(BuildContext context) {
    // 内容区优先显示当前打开的工具
    final tool = _currentTool;
    if (tool != null) {
      return KeyedSubtree(
        key: ValueKey('pane-${tool.id}'),
        child: tool.builder(context),
      );
    }
    switch (_selectedIndex) {
      case 1:
        final settings = ToolRegistry.of('settings');
        return KeyedSubtree(
          key: const ValueKey('pane-settings'),
          child: settings.builder(context),
        );
      case 2:
        final about = ToolRegistry.aboutTools.first;
        return KeyedSubtree(
          key: const ValueKey('pane-about'),
          child: about.builder(context),
        );
      default:
        return HomePage(
          key: const ValueKey('pane-home'),
          searchFocusNode: _searchFocus,
          onToolTap: (t) => _openTool(context, t),
        );
    }
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
      body: Column(
        children: [
          RunningSessionsBar(onOpenTool: (id) => _openToolById(context, id)),
          Expanded(
            child: HomePage(onToolTap: (t) => _openTool(context, t)),
          ),
        ],
      ),
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
          ListTile(
            leading: const Icon(Icons.home_rounded),
            title: const Text('首页'),
            dense: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          for (var i = 1; i < _sidebarTools.length; i++)
            _drawerTile(context, _sidebarTools[i]!),
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

  Widget _drawerTile(BuildContext context, ToolInfo tool) {
    return ListTile(
      leading: Icon(tool.icon),
      title: Text(tool.name),
      dense: true,
      onTap: () {
        Navigator.of(context).pop();
        _openTool(context, tool);
      },
    );
  }
}

/// 桌面端左侧导航栏：仅骨架入口（首页 / 设置 / 关于）。
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.sidebarTools,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<ToolInfo?> sidebarTools;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = Responsive.isTablet(context) ? 200.0 : 220.0;

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
            // 骨架导航（固定 3 项，无需滚动）
            for (var i = 0; i < sidebarTools.length; i++)
              _sidebarTile(context, i, i == selectedIndex),
            const Spacer(),
            // 快捷提示
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard_command_key_rounded,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ctrl+K 快速搜索工具',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarTile(BuildContext context, int index, bool selected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tool = sidebarTools[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              color: selected ? AppThemeSeed.primary : Colors.transparent,
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
              selectedTileColor:
                  colorScheme.primaryContainer.withValues(alpha: 0.55),
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  }
}
