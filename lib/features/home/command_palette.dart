import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';

/// 命令面板（桌面端 Ctrl+K）：搜索并快速打开任意工具。
Future<void> showCommandPalette(
  BuildContext context, {
  required ValueChanged<ToolInfo> onSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 460,
        height: 400,
        child: _CommandPaletteContent(onSelected: onSelected),
      ),
    ),
  );
}

class _CommandPaletteContent extends StatefulWidget {
  const _CommandPaletteContent({required this.onSelected});

  final ValueChanged<ToolInfo> onSelected;

  @override
  State<_CommandPaletteContent> createState() => _CommandPaletteContentState();
}

class _CommandPaletteContentState extends State<_CommandPaletteContent> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  int _highlight = 0;

  List<ToolInfo> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return ToolRegistry.tools;
    return ToolRegistry.tools
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.tags.any((tag) => tag.toLowerCase().contains(q)))
        .toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pick(ToolInfo tool) {
    Navigator.of(context).pop();
    widget.onSelected(tool);
  }

  void _move(int delta) {
    final n = _results.length;
    if (n == 0) return;
    setState(() => _highlight = (_highlight + delta + n) % n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = _results;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.escape):
            () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) => setState(() {
              _query = v;
              _highlight = 0;
            }),
            onSubmitted: (_) {
              if (results.isNotEmpty) _pick(results[_highlight]);
            },
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '搜索工具并回车打开…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('没有匹配的工具'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final tool = results[index];
                    final selected = index == _highlight;
                    return MouseRegion(
                      onEnter: (_) => setState(() => _highlight = index),
                      child: ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      leading: Icon(
                        tool.icon,
                        size: 20,
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : BrandColors.primary,
                      ),
                      title: Text(
                        tool.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        tool.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => _pick(tool),
                    ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Text(
                '↑↓ 选择 · Enter 打开 · Esc 关闭',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.outline),
              ),
              const Spacer(),
              Text(
                '${results.length} 个工具',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: colorScheme.outline),
              ),
            ],
          ),
        ),
        ],
        ),
      ),
    );
  }
}
