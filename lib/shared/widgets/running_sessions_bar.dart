import 'package:flutter/material.dart';

import '../../core/session/session_registry.dart';
import '../../core/session/tool_session.dart';
import '../../core/theme/app_tokens.dart';

/// 运行状态条：常驻显示所有运行中的工具会话，点击回跳、可停止。
class RunningSessionsBar extends StatelessWidget {
  const RunningSessionsBar({super.key, required this.onOpenTool});

  /// 点击胶囊回跳工具（参数为工具 id）。
  final ValueChanged<String> onOpenTool;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionRegistry.instance,
      builder: (context, _) {
        final running = SessionRegistry.instance.running;
        if (running.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final session in running) ...[
                        _SessionChip(session: session, onOpenTool: onOpenTool),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.session, required this.onOpenTool});

  final ToolSession session;
  final ValueChanged<String> onOpenTool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => onOpenTool(session.toolId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 运行指示点
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: BrandColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                session.statusLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                session.statusText,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '停止 ${session.statusLabel}',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: session.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
