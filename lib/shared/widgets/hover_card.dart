import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 可交互卡片：统一卡片表面 + 桌面端悬停抬升反馈。
///
/// 采用「表面 + 描边」的轻量分层，hover 时轻微抬升并加强阴影，
/// 移动端无 hover（由按压波纹反馈）。
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.padding,
    this.borderRadius = AppRadius.lg,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Clip clipBehavior;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
      child: widget.child,
    );

    final card = Card(
      elevation: _hovered ? 1 : 0,
      margin: EdgeInsets.zero,
      clipBehavior: widget.clipBehavior,
      color: widget.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: _hovered ? 0.7 : 0.45,
          ),
        ),
      ),
      child: widget.onTap == null && widget.onLongPress == null
          ? content
          : InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: content,
            ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.008 : 1.0,
        duration: AppMotion.quick,
        curve: AppMotion.easeOut,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -1.5 : 0, 0),
          child: card,
        ),
      ),
    );
  }
}
