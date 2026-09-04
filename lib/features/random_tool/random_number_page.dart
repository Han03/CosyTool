import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 随机工具：数字 / 密码 / 投掷 / UUID 多种随机模式，带历史记录。
class RandomNumberPage extends StatefulWidget {
  const RandomNumberPage({super.key});

  @override
  State<RandomNumberPage> createState() => _RandomNumberPageState();
}

enum _Mode { number, password, toss, uuid }

class _RandomNumberPageState extends State<RandomNumberPage> {
  static final ToolInfo _tool = ToolRegistry.of('random');

  _Mode _mode = _Mode.number;

  // 数字
  final TextEditingController _minCtrl = TextEditingController(text: '1');
  final TextEditingController _maxCtrl = TextEditingController(text: '100');
  final TextEditingController _countCtrl = TextEditingController(text: '1');
  bool _unique = false;

  // 密码
  final TextEditingController _passLenCtrl = TextEditingController(text: '12');
  bool _useLower = true;
  bool _useUpper = true;
  bool _useDigit = true;
  bool _useSymbol = false;

  String _result = '';
  String? _error;
  final List<_HistoryEntry> _history = [];

  final Random _rng = Random();
  final Random _secure = Random.secure();

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _countCtrl.dispose();
    _passLenCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    switch (_mode) {
      case _Mode.number:
        _generateNumber();
      case _Mode.password:
        _generatePassword();
      case _Mode.toss:
        _generateToss();
      case _Mode.uuid:
        _generateUuid();
    }
  }

  void _generateNumber() {
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    final count = int.tryParse(_countCtrl.text.trim());
    if (min == null || max == null || count == null || min > max || count <= 0) {
      setState(() {
        _error = '请填写合法参数：最小值 ≤ 最大值，个数 ≥ 1';
        _result = '';
      });
      return;
    }
    if (_unique && count > (max - min + 1)) {
      setState(() {
        _error = '去重模式下个数不能超过区间长度';
        _result = '';
      });
      return;
    }
    final List<int> list;
    if (_unique) {
      final pool = List<int>.generate(max - min + 1, (i) => min + i)..shuffle(_rng);
      list = pool.take(count).toList();
    } else {
      list = List<int>.generate(count, (_) => min + _rng.nextInt(max - min + 1));
    }
    setState(() {
      _result = list.join(', ');
      _error = null;
      _history.insert(0, _HistoryEntry('随机数', _result));
      if (_history.length > 20) _history.removeLast();
    });
  }

  void _generatePassword() {
    final len = int.tryParse(_passLenCtrl.text.trim());
    if (len == null || len <= 0 || len > 64) {
      setState(() {
        _error = '请输入 1 - 64 之间的密码长度';
        _result = '';
      });
      return;
    }
    final lower = 'abcdefghijklmnopqrstuvwxyz';
    final upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final digit = '0123456789';
    final symbol = '!@#\$%^&*()-_=+[]{};:,.?';
    final pools = <String>[];
    if (_useLower) pools.add(lower);
    if (_useUpper) pools.add(upper);
    if (_useDigit) pools.add(digit);
    if (_useSymbol) pools.add(symbol);
    if (pools.isEmpty) {
      setState(() {
        _error = '请至少选择一种字符集';
        _result = '';
      });
      return;
    }
    final all = pools.join();
    final buf = StringBuffer();
    for (var i = 0; i < len; i++) {
      buf.write(all[_secure.nextInt(all.length)]);
    }
    setState(() {
      _result = buf.toString();
      _error = null;
      _history.insert(0, _HistoryEntry('密码', _result));
      if (_history.length > 20) _history.removeLast();
    });
  }

  void _generateToss() {
    final r = _secure.nextDouble();
    setState(() {
      _result = r < 0.5 ? '正面' : '反面';
      _error = null;
      _history.insert(0, _HistoryEntry('抛硬币', _result));
      if (_history.length > 20) _history.removeLast();
    });
  }

  void _generateYesNo() {
    setState(() {
      _result = _secure.nextBool() ? '是' : '否';
      _error = null;
      _history.insert(0, _HistoryEntry('随机判断', _result));
      if (_history.length > 20) _history.removeLast();
    });
  }

  void _generateUuid() {
    setState(() {
      _result = _uuidV4();
      _error = null;
      _history.insert(0, _HistoryEntry('UUID', _result));
      if (_history.length > 20) _history.removeLast();
    });
  }

  String _uuidV4() {
    final r = _secure;
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}-'
        '${hex(b[4])}${hex(b[5])}-'
        '${hex(b[6])}${hex(b[7])}-'
        '${hex(b[8])}${hex(b[9])}-'
        '${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }

  Future<void> _copy() async {
    if (_result.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _result));
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
        if (_result.isNotEmpty)
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
                  SegmentedButton<_Mode>(
                    segments: const [
                      ButtonSegment(value: _Mode.number, label: Text('数字'), icon: Icon(Icons.tag_rounded, size: 18)),
                      ButtonSegment(value: _Mode.password, label: Text('密码'), icon: Icon(Icons.password_rounded, size: 18)),
                      ButtonSegment(value: _Mode.toss, label: Text('投掷'), icon: Icon(Icons.currency_bitcoin_rounded, size: 18)),
                      ButtonSegment(value: _Mode.uuid, label: Text('UUID'), icon: Icon(Icons.fingerprint_rounded, size: 18)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  ..._buildModeControls(theme, colorScheme),
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
                    label: Text(_mode == _Mode.toss ? '抛一次' : '生成'),
                  ),
                  const SizedBox(height: 24),
                  if (_result.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        _result,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '历史记录（点按复制）',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._history.take(12).map((h) => Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: ListTile(
                            dense: true,
                            leading: Text(
                              h.label,
                              style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            title: Text(
                              h.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(ClipboardData(text: h.value));
                              messenger.showSnackBar(
                                const SnackBar(content: Text('已复制到剪贴板')),
                              );
                            },
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildModeControls(ThemeData theme, ColorScheme colorScheme) {
    switch (_mode) {
      case _Mode.number:
        return [
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
        ];
      case _Mode.password:
        return [
          TextField(
            controller: _passLenCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '密码长度（1-64）'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('小写 a-z'),
                selected: _useLower,
                onSelected: (v) => setState(() => _useLower = v),
              ),
              FilterChip(
                label: const Text('大写 A-Z'),
                selected: _useUpper,
                onSelected: (v) => setState(() => _useUpper = v),
              ),
              FilterChip(
                label: const Text('数字 0-9'),
                selected: _useDigit,
                onSelected: (v) => setState(() => _useDigit = v),
              ),
              FilterChip(
                label: const Text('符号'),
                selected: _useSymbol,
                onSelected: (v) => setState(() => _useSymbol = v),
              ),
            ],
          ),
        ];
      case _Mode.toss:
        return [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateToss,
                  icon: const Icon(Icons.monetization_on_rounded),
                  label: const Text('抛硬币'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateYesNo,
                  icon: const Icon(Icons.help_rounded),
                  label: const Text('是 / 否'),
                ),
              ),
            ],
          ),
        ];
      case _Mode.uuid:
        return [
          const Text(
            '生成一个随机 UUID v4（16 字节随机数，128 位）',
            style: TextStyle(fontSize: 13),
          ),
        ];
    }
  }
}

class _HistoryEntry {
  const _HistoryEntry(this.label, this.value);

  final String label;
  final String value;
}
