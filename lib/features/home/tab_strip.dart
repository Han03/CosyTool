import 'package:flutter/material.dart';

import '../../models/tool_info.dart';

/// 桌面端工具多开 Tab 条：浏览器式标签。
///
/// 视觉设计（docs/tab_strip_optimization_plan.md）：
/// - 激活 Tab 与内容区无缝连接（顶部 2px 品牌绿指示条 + 与内容同色背景，
///   顶部圆角、底部直角，形成"长在内容上"的锚定感）
/// - 激活指示条随 Tab 切换滑动（200ms easeOutCubic）
/// - hover 显示关闭按钮（触屏常显）；未激活 hover 提亮
/// - 溢出时左右品牌绿渐变遮罩提示可滚动
class TabStrip extends StatefulWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  final List<ToolInfo> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  @override
  State<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<TabStrip> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _stripKey = GlobalKey();
  final List<GlobalKey> _tabKeys = [];

  double _indicatorLeft = 0;
  double _indicatorWidth = 0;
  bool _indicatorAnim = true;
  bool _showLeftFade = false;
  bool _showRightFade = false;
  bool _touch = false;

  @override
  void initState() {
    super.initState();
    _touch = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    _syncKeys();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(TabStrip old) {
    super.didUpdateWidget(old);
    if (old.tabs.length != widget.tabs.length) _syncKeys();
    if (old.activeIndex != widget.activeIndex) {
      _scrollToActive();
      _scheduleMeasure();
    } else if (old.tabs.length != widget.tabs.length) {
      _scheduleMeasure();
    }
  }

  void _syncKeys() {
    if (_tabKeys.length != widget.tabs.length) {
      _tabKeys
        ..clear()
        ..addAll(List.generate(widget.tabs.length, (_) => GlobalKey()));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final left = pos.pixels > 2;
    final right = pos.pixels < pos.maxScrollExtent - 2;
    if (left != _showLeftFade || right != _showRightFade) {
      setState(() {
        _showLeftFade = left;
        _showRightFade = right;
      });
    }
    _measureIndicator(animate: false);
  }

  void _scrollToActive() {
    final idx = widget.activeIndex;
    if (idx < 0 || idx >= _tabKeys.length) return;
    final ctx = _tabKeys[idx].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureIndicator();
    });
  }

  void _measureIndicator({bool animate = true}) {
    final idx = widget.activeIndex;
    if (idx < 0 || idx >= _tabKeys.length) {
      if (_indicatorWidth != 0) {
        setState(() {
          _indicatorLeft = 0;
          _indicatorWidth = 0;
        });
      }
      return;
    }
    final box = _tabKeys[idx].currentContext?.findRenderObject() as RenderBox?;
    final stripBox = _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stripBox == null || !box.hasSize || !stripBox.hasSize) {
      return;
    }
    final pos = box.localToGlobal(Offset.zero);
    final stripPos = stripBox.localToGlobal(Offset.zero);
    setState(() {
      _indicatorAnim = animate;
      _indicatorLeft = pos.dx - stripPos.dx;
      _indicatorWidth = box.size.width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: _stripKey,
      height: 44,
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
      child: Stack(
        children: [
          // 激活背景：顶部品牌绿指示条 + 与内容同色，随激活 Tab 滑动
          AnimatedPositioned(
            duration: _indicatorAnim
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            left: _indicatorLeft,
            width: _indicatorWidth,
            top: 3,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                border: Border(
                  top: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          // 左溢出渐变
          Positioned(
            left: 0,
            top: 3,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _showLeftFade ? 1 : 0,
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surfaceContainerLowest,
                        colorScheme.surfaceContainerLowest.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 右溢出渐变
          Positioned(
            right: 0,
            top: 3,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _showRightFade ? 1 : 0,
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        colorScheme.surfaceContainerLowest,
                        colorScheme.surfaceContainerLowest.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tab 列表
          ListView.separated(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
            itemCount: widget.tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tool = widget.tabs[index];
              return _TabItem(
                key: _tabKeys[index],
                tool: tool,
                active: index == widget.activeIndex,
                touch: _touch,
                onTap: () => widget.onSelect(index),
                onClose: () => widget.onClose(index),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    super.key,
    required this.tool,
    required this.active,
    required this.touch,
    required this.onTap,
    required this.onClose,
  });

  final ToolInfo tool;
  final bool active;
  final bool touch;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showClose = _hover || widget.touch;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 39,
        decoration: BoxDecoration(
          color: widget.active
              ? Colors.transparent
              : _hover
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
          borderRadius: widget.active
              ? const BorderRadius.vertical(top: Radius.circular(10))
              : BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  Icon(
                    widget.tool.icon,
                    size: 16,
                    color: widget.active
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      widget.tool.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            widget.active ? FontWeight.w700 : FontWeight.w500,
                        color: widget.active
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: showClose ? 1 : 0,
                    child: IconButton(
                      tooltip: '关闭 ${widget.tool.name}',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: widget.onClose,
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
}
