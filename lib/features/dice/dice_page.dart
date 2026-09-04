import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 骰子工具：支持 1 - 3 个骰子、D4~D20 多种面数，带滚动动画与历史记录。
class DicePage extends StatefulWidget {
  const DicePage({super.key});

  @override
  State<DicePage> createState() => _DicePageState();
}

class _DicePageState extends State<DicePage> {
  static final ToolInfo _tool = ToolRegistry.of('dice');

  final Random _random = Random();
  int _count = 1;
  int _sides = 6;
  late List<int> _values = List.filled(_count, 1);
  bool _rolling = false;
  double _spin = 0;
  final List<List<int>> _history = [];

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    // 快速切换制造滚动效果 + 自旋
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() {
        _spin += (i.isEven ? 1 : -1) * 0.35;
        for (var d = 0; d < _count; d++) {
          _values[d] = 1 + _random.nextInt(_sides);
        }
      });
    }
    if (!mounted) return;
    setState(() {
      _rolling = false;
      _history.insert(0, List.of(_values));
      if (_history.length > 12) _history.removeLast();
    });
  }

  void _setCount(int c) {
    if (_rolling) return;
    setState(() {
      _count = c;
      _values = List.filled(c, 1);
    });
  }

  void _setSides(int s) {
    if (_rolling) return;
    setState(() {
      _sides = s;
      _values = List.filled(_count, 1);
    });
  }

  int get _sum => _values.fold<int>(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const Spacer(),
                // 骰子区
                AnimatedRotation(
                  turns: _spin / (2 * pi),
                  duration: const Duration(milliseconds: 150),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (var i = 0; i < _count; i++)
                        _Die(value: _values[i], sides: _sides),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '合计 $_sum',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // 面数选择
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in [4, 6, 8, 10, 12, 20])
                      ChoiceChip(
                        label: Text('D$s'),
                        selected: _sides == s,
                        onSelected: (_) => _setSides(s),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _roll,
                  icon: const Icon(Icons.casino_rounded),
                  label: Text(_rolling ? '滚动中…' : '摇骰子'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
                // 历史记录
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final roll = _history[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                roll.join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                '合计 ${roll.fold<int>(0, (a, b) => a + b)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个骰子渲染（数字面，支持多面骰）。
class _Die extends StatelessWidget {
  const _Die({required this.value, required this.sides});

  final int value;
  final int sides;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = sides > 6 ? 72.0 : 88.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(sides > 6 ? 22 : 18),
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
            fontSize: sides > 6 ? 32 : 40,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
