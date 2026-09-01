import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 骰子工具：支持 1 - 3 个骰子，带滚动动画。
class DicePage extends StatefulWidget {
  const DicePage({super.key});

  @override
  State<DicePage> createState() => _DicePageState();
}

class _DicePageState extends State<DicePage> {
  static final ToolInfo _tool = ToolRegistry.of('dice');

  final Random _random = Random();
  int _count = 1;
  late List<int> _values = List.filled(_count, 1);
  bool _rolling = false;

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    // 快速切换制造滚动效果
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() {
        for (var d = 0; d < _count; d++) {
          _values[d] = 1 + _random.nextInt(6);
        }
      });
    }
    if (!mounted) return;
    setState(() => _rolling = false);
  }

  void _setCount(int c) {
    if (_rolling) return;
    setState(() {
      _count = c;
      _values = List.filled(c, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sum = _values.fold<int>(0, (a, b) => a + b);

    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  // 骰子区
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (var i = 0; i < _count; i++) _Die(value: _values[i]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _count > 1 ? '合计 $sum' : ' ',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // 数量选择
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1 个'), icon: Icon(Icons.looks_one_rounded)),
                      ButtonSegment(value: 2, label: Text('2 个'), icon: Icon(Icons.looks_two_rounded)),
                      ButtonSegment(value: 3, label: Text('3 个'), icon: Icon(Icons.looks_3_rounded)),
                    ],
                    selected: {_count},
                    onSelectionChanged: (s) => _setCount(s.first),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _roll,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('摇骰子'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 48),
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

/// 单个骰子渲染。
class _Die extends StatelessWidget {
  const _Die({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
