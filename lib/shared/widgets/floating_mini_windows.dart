import 'package:flutter/material.dart';

import '../../core/session/session_registry.dart';
import '../../core/session/tool_session.dart';
import '../../core/theme/app_tokens.dart';

/// 桌面端悬浮小窗层：小窗化的运行中会话以可拖动迷你面板置顶显示。
///
/// 面板位置由外部维护（[offsets]），本层只负责渲染与拖动回调；
/// 面板随会话运行实时刷新，停止后自动收起。
class FloatingMiniWindows extends StatelessWidget {
  const FloatingMiniWindows({
    super.key,
    required this.onOpenTool,
    required this.offsets,
    required this.onOffsetChanged,
  });

  /// 点击面板主体回跳工具（参数为工具 id）。
  final ValueChanged<String> onOpenTool;

  /// 各会话当前偏移（未记录时从右上角堆叠）。
  final Map<String, Offset> offsets;

  /// 拖动结束 / 过程中更新偏移。
  final void Function(String toolId, Offset offset) onOffsetChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionRegistry.instance,
      builder: (context, _) {
        final pinned = SessionRegistry.instance.pinnedRunning;
        if (pinned.isEmpty) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            return Stack(
              children: [
                for (var i = 0; i < pinned.length; i++)
                  _MiniPanel(
                    key: ValueKey(pinned[i].toolId),
                    session: pinned[i],
                    index: i,
                    bounds: Size(maxW, maxH),
                    offset: offsets[pinned[i].toolId],
                    onOpenTool: onOpenTool,
                    onOffsetChanged: onOffsetChanged,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MiniPanel extends StatefulWidget {
  const _MiniPanel({
    super.key,
    required this.session,
    required this.index,
    required this.bounds,
    required this.offset,
    required this.onOpenTool,
    required this.onOffsetChanged,
  });

  final ToolSession session;
  final int index;
  final Size bounds;
  final Offset? offset;
  final ValueChanged<String> onOpenTool;
  final void Function(String toolId, Offset offset) onOffsetChanged;

  @override
  State<_MiniPanel> createState() => _MiniPanelState();
}

class _MiniPanelState extends State<_MiniPanel> {
  static const double _width = 248;
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.offset ??
        Offset(
          widget.bounds.width - _width - 20 - widget.index * 28,
          widget.index * 28 + 16,
        );
  }

  @override
  void didUpdateWidget(_MiniPanel old) {
    super.didUpdateWidget(old);
    if (widget.offset != null && widget.offset != old.offset) {
      _pos = widget.offset!;
    }
  }

  @override
  void dispose() {
    // 会话停止导致面板移除时，清除小窗标记（不通知，避免 dispose 期报错）
    if (widget.session.pinned && !widget.session.isRunning) {
      widget.session.pinned = false;
    }
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _pos = Offset(
        (_pos.dx + details.delta.dx)
            .clamp(8.0, widget.bounds.width - _width - 8),
        (_pos.dy + details.delta.dy)
            .clamp(8.0, widget.bounds.height - 96),
      );
    });
    widget.onOffsetChanged(widget.session.toolId, _pos);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        child: Material(
          elevation: 12,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              final theme = Theme.of(context);
              return SizedBox(
                width: _width,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: BrandColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.statusLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '恢复主区',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.picture_in_picture_alt_rounded),
                            onPressed: () => session.setPinned(false),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Text(
                          session.statusText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (session.canPause)
                            IconButton(
                              tooltip: '暂停 / 继续',
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              icon: Icon(
                                session.isRunning
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              onPressed: session.togglePause,
                            ),
                          IconButton(
                            tooltip: '停止 ${session.statusLabel}',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            icon: const Icon(Icons.stop_circle_outlined),
                            onPressed: session.stop,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () =>
                                widget.onOpenTool(session.toolId),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('打开'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
