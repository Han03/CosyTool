import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 随机数工具：区间内生成指定个数（支持去重）。
class RandomNumberPage extends StatefulWidget {
  const RandomNumberPage({super.key});

  @override
  State<RandomNumberPage> createState() => _RandomNumberPageState();
}

class _RandomNumberPageState extends State<RandomNumberPage> {
  static final ToolInfo _tool = ToolRegistry.of('random');

  final TextEditingController _minCtrl = TextEditingController(text: '1');
  final TextEditingController _maxCtrl = TextEditingController(text: '100');
  final TextEditingController _countCtrl = TextEditingController(text: '1');

  bool _unique = false;
  List<int> _results = const [];
  String? _error;

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    final count = int.tryParse(_countCtrl.text.trim());
    if (min == null || max == null || count == null || min > max || count <= 0) {
      setState(() {
        _error = '请填写合法参数：最小值 ≤ 最大值，个数 ≥ 1';
        _results = const [];
      });
      return;
    }
    if (_unique && count > (max - min + 1)) {
      setState(() {
        _error = '去重模式下个数不能超过区间长度';
        _results = const [];
      });
      return;
    }
    final rng = Random();
    final List<int> list;
    if (_unique) {
      final pool = List<int>.generate(max - min + 1, (i) => min + i)..shuffle(rng);
      list = pool.take(count).toList();
    } else {
      list = List<int>.generate(count, (_) => min + rng.nextInt(max - min + 1));
    }
    setState(() {
      _results = list;
      _error = null;
    });
  }

  Future<void> _copy() async {
    if (_results.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _results.join(', ')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ToolPageScaffold(
      tool: _tool,
      actions: [
        if (_results.isNotEmpty)
          IconButton(
            tooltip: '复制结果',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copy,
          ),
      ],
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '最小值'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '最大值'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '生成个数'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('不重复'),
                          value: _unique,
                          onChanged: (v) => setState(() => _unique = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: colorScheme.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('生成随机数'),
                  ),
                  const SizedBox(height: 24),
                  if (_results.isNotEmpty) ...[
                    Text(
                      '生成结果',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final r in _results)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$r',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
