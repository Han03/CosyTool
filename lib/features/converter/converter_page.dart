import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';

/// 单位换算工具：长度 / 重量 / 温度 / 面积 / 体积 / 速度 / 时间 / 数据存储。
class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  static final ToolInfo _tool = ToolRegistry.of('converter');

  int _categoryIndex = 0;
  int _fromIndex = 0;
  int _toIndex = 1;
  final TextEditingController _input = TextEditingController(text: '1');
  String _output = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _convert() {
    final value = double.tryParse(_input.text.trim());
    if (value == null) {
      setState(() => _output = '');
      return;
    }
    final category = _categories[_categoryIndex];
    final base = category.toBase(value, _fromIndex);
    final result = category.fromBase(base, _toIndex);
    setState(() {
      _output = _format(result);
    });
  }

  String _format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _swap() {
    setState(() {
      final t = _fromIndex;
      _fromIndex = _toIndex;
      _toIndex = t;
    });
    _convert();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = _categories[_categoryIndex];
    final fromUnit = category.units[_fromIndex];
    final toUnit = category.units[_toIndex];

    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 类别选择
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _categories.length; i++)
                        ChoiceChip(
                          avatar: Icon(_categories[i].icon, size: 16),
                          label: Text(_categories[i].name),
                          selected: _categoryIndex == i,
                          onSelected: (_) {
                            setState(() {
                              _categoryIndex = i;
                              _fromIndex = 0;
                              _toIndex = _categories[i].units.length > 1 ? 1 : 0;
                            });
                            _convert();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 输入区
                  TextField(
                    controller: _input,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '数值',
                      suffixText: fromUnit.symbol,
                    ),
                    onChanged: (_) => _convert(),
                  ),
                  const SizedBox(height: 16),
                  // 单位选择 + 交换
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('from-$_fromIndex'),
                          isExpanded: true,
                          initialValue: _fromIndex,
                          decoration: const InputDecoration(labelText: '从'),
                          items: [
                            for (var i = 0; i < category.units.length; i++)
                              DropdownMenuItem(value: i, child: Text('${category.units[i].name} (${category.units[i].symbol})')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _fromIndex = v);
                            _convert();
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: '交换',
                        icon: const Icon(Icons.swap_horiz_rounded),
                        onPressed: _swap,
                      ),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('to-$_toIndex'),
                          isExpanded: true,
                          initialValue: _toIndex,
                          decoration: const InputDecoration(labelText: '到'),
                          items: [
                            for (var i = 0; i < category.units.length; i++)
                              DropdownMenuItem(value: i, child: Text('${category.units[i].name} (${category.units[i].symbol})')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _toIndex = v);
                            _convert();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // 结果卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primaryContainer.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '换算结果',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _output.isEmpty ? '—' : '$_output ${toUnit.symbol}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fromUnit.name} → ${toUnit.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _output.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: _output));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('已复制结果')));
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('复制结果'),
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

class _Unit {
  const _Unit(this.name, this.symbol, this.factor);

  final String name;
  final String symbol;
  /// 换算到基准单位的乘数。
  final double factor;
}

class _Category {
  const _Category(this.name, this.icon, this.units, {this.isTemperature = false});

  final String name;
  final IconData icon;
  final List<_Unit> units;
  final bool isTemperature;

  double toBase(double value, int index) {
    if (isTemperature) return _temperatureToCelsius(value, index);
    return value * units[index].factor;
  }

  double fromBase(double base, int index) {
    if (isTemperature) return _celsiusToTemperature(base, index);
    return base / units[index].factor;
  }

  static double _temperatureToCelsius(double v, int i) {
    // 0: °C  1: °F  2: K
    switch (i) {
      case 1:
        return (v - 32) * 5 / 9;
      case 2:
        return v - 273.15;
      default:
        return v;
    }
  }

  static double _celsiusToTemperature(double c, int i) {
    switch (i) {
      case 1:
        return c * 9 / 5 + 32;
      case 2:
        return c + 273.15;
      default:
        return c;
    }
  }
}

const List<_Category> _categories = [
  _Category('长度', Icons.straighten_rounded, [
    _Unit('毫米', 'mm', 0.001),
    _Unit('厘米', 'cm', 0.01),
    _Unit('米', 'm', 1),
    _Unit('千米', 'km', 1000),
    _Unit('英寸', 'in', 0.0254),
    _Unit('英尺', 'ft', 0.3048),
    _Unit('码', 'yd', 0.9144),
    _Unit('英里', 'mi', 1609.344),
  ]),
  _Category('重量', Icons.monitor_weight_rounded, [
    _Unit('毫克', 'mg', 0.000001),
    _Unit('克', 'g', 0.001),
    _Unit('千克', 'kg', 1),
    _Unit('吨', 't', 1000),
    _Unit('盎司', 'oz', 0.0283495231),
    _Unit('磅', 'lb', 0.45359237),
  ]),
  _Category('温度', Icons.thermostat_rounded, [
    _Unit('摄氏度', '°C', 1),
    _Unit('华氏度', '°F', 1),
    _Unit('开尔文', 'K', 1),
  ], isTemperature: true),
  _Category('面积', Icons.square_foot_rounded, [
    _Unit('平方米', 'm²', 1),
    _Unit('平方千米', 'km²', 1000000),
    _Unit('公顷', 'ha', 10000),
    _Unit('亩', '亩', 666.6667),
    _Unit('英亩', 'acre', 4046.8564224),
    _Unit('平方英尺', 'ft²', 0.09290304),
  ]),
  _Category('体积', Icons.water_drop_rounded, [
    _Unit('毫升', 'mL', 0.001),
    _Unit('升', 'L', 1),
    _Unit('立方米', 'm³', 1000),
    _Unit('加仑(美)', 'gal', 3.785411784),
    _Unit('杯', 'cup', 0.24),
  ]),
  _Category('速度', Icons.speed_rounded, [
    _Unit('米/秒', 'm/s', 1),
    _Unit('千米/时', 'km/h', 1 / 3.6),
    _Unit('英里/时', 'mph', 0.44704),
    _Unit('节', 'kn', 0.514444),
  ]),
  _Category('时间', Icons.schedule_rounded, [
    _Unit('秒', 's', 1),
    _Unit('分钟', 'min', 60),
    _Unit('小时', 'h', 3600),
    _Unit('天', 'd', 86400),
    _Unit('周', '周', 604800),
  ]),
  _Category('数据存储', Icons.storage_rounded, [
    _Unit('字节', 'B', 1),
    _Unit('千字节', 'KB', 1024),
    _Unit('兆字节', 'MB', 1024 * 1024),
    _Unit('吉字节', 'GB', 1024 * 1024 * 1024),
    _Unit('太字节', 'TB', 1024 * 1024 * 1024 * 1024),
  ]),
  _Category('压力', Icons.compress_rounded, [
    _Unit('帕斯卡', 'Pa', 1),
    _Unit('千帕', 'kPa', 1000),
    _Unit('兆帕', 'MPa', 1000000),
    _Unit('巴', 'bar', 100000),
    _Unit('标准大气压', 'atm', 101325),
    _Unit('磅力/平方英寸', 'psi', 6894.7572932),
    _Unit('毫米汞柱', 'mmHg', 133.322387415),
  ]),
  _Category('能量', Icons.bolt_rounded, [
    _Unit('焦耳', 'J', 1),
    _Unit('千焦', 'kJ', 1000),
    _Unit('卡路里', 'cal', 4.184),
    _Unit('千卡', 'kcal', 4184),
    _Unit('瓦时', 'Wh', 3600),
    _Unit('千瓦时', 'kWh', 3600000),
    _Unit('电子伏', 'eV', 1.602176634e-19),
  ]),
  _Category('功率', Icons.power_rounded, [
    _Unit('瓦特', 'W', 1),
    _Unit('千瓦', 'kW', 1000),
    _Unit('兆瓦', 'MW', 1000000),
    _Unit('马力(米制)', 'PS', 735.49875),
    _Unit('马力(英制)', 'hp', 745.699871582),
  ]),
  _Category('角度', Icons.rotate_right_rounded, [
    _Unit('度', '°', 1),
    _Unit('弧度', 'rad', 57.2957795131),
    _Unit('角分', "'", 1 / 60),
    _Unit('角秒', '"', 1 / 3600),
  ]),
  _Category('频率', Icons.graphic_eq_rounded, [
    _Unit('赫兹', 'Hz', 1),
    _Unit('千赫', 'kHz', 1000),
    _Unit('兆赫', 'MHz', 1000000),
    _Unit('吉赫', 'GHz', 1000000000),
  ]),
];
