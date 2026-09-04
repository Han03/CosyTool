import 'dart:async';

import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';

import '../../core/utils/platform_check.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../../shared/widgets/unsupported_platform.dart';

/// 手电筒工具：调用闪光灯照明（仅移动端），支持常亮 / 频闪 / SOS。
class FlashlightPage extends StatefulWidget {
  const FlashlightPage({super.key});

  @override
  State<FlashlightPage> createState() => _FlashlightPageState();
}

enum _FlashMode { off, on, strobe, sos }

class _FlashlightPageState extends State<FlashlightPage> {
  static final ToolInfo _tool = ToolRegistry.of('flashlight');

  bool? _available;
  _FlashMode _mode = _FlashMode.off;
  double _freq = 5; // 频闪频率 Hz
  Timer? _patternTimer;
  bool _torchState = false;

  @override
  void initState() {
    super.initState();
    if (PlatformCheck.hasFlashlightSupport) _check();
  }

  Future<void> _check() async {
    try {
      final ok = await TorchLight.isTorchAvailable();
      if (!mounted) return;
      setState(() => _available = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _available = false);
    }
  }

  Future<void> _setTorch(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      _torchState = on;
    } catch (_) {}
  }

  Future<void> _switchMode(_FlashMode m) async {
    if (_mode == m && m != _FlashMode.strobe) return;
    _patternTimer?.cancel();
    _patternTimer = null;
    switch (m) {
      case _FlashMode.off:
        await _setTorch(false);
      case _FlashMode.on:
        await _setTorch(true);
      case _FlashMode.strobe:
        await _setTorch(false);
        _startStrobe();
      case _FlashMode.sos:
        await _setTorch(false);
        _startSos();
    }
    if (!mounted) return;
    setState(() => _mode = m);
  }

  void _startStrobe() {
    final halfPeriod = (500 / _freq).round().clamp(30, 500);
    _patternTimer = Timer.periodic(Duration(milliseconds: halfPeriod), (_) async {
      await _setTorch(!_torchState);
    });
  }

  /// SOS 闪烁序列（ms）：S=3短 · O=3长 · S=3短，循环。
  static const List<int> _sosSegments = [
    150, 150, 150, 150, 150, 300, // S
    600, 150, 600, 150, 600, 300, // O
    150, 150, 150, 150, 150, 700, // S + 间隔
  ];

  int _sosIndex = 0;

  void _startSos() {
    _sosIndex = 0;
    _patternTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      final isOn = _sosIndex.isEven;
      await _setTorch(isOn);
      _sosIndex = (_sosIndex + 1) % (_sosSegments.length + 1);
      if (_sosIndex == _sosSegments.length) {
        _patternTimer?.cancel();
        _startSos();
      }
    });
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
    TorchLight.disableTorch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCheck.hasFlashlightSupport) {
      return ToolPageScaffold(
        tool: _tool,
        child: UnsupportedPlatformView(
          toolName: _tool.name,
          icon: _tool.icon,
        ),
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOn = _mode != _FlashMode.off;

    return ToolPageScaffold(
      tool: _tool,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: isOn ? const Color(0xFFFDF3D7) : colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_available == false) ...[
                    Icon(Icons.flashlight_off_rounded, size: 48, color: colorScheme.error),
                    const SizedBox(height: 12),
                    const Text('当前设备没有可用的闪光灯'),
                    const SizedBox(height: 24),
                  ] else ...[
                    Material(
                      color: isOn ? const Color(0xFFF5C542) : colorScheme.surfaceContainerHighest,
                      shape: const CircleBorder(),
                      elevation: isOn ? 12 : 3,
                      shadowColor: const Color(0xFFF5C542).withValues(alpha: 0.5),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _switchMode(_mode == _FlashMode.off ? _FlashMode.on : _FlashMode.off),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: Icon(
                            isOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                            size: 68,
                            color: isOn ? Colors.black87 : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      switch (_mode) {
                        _FlashMode.off => '点击开启手电筒',
                        _FlashMode.on => '常亮照明中',
                        _FlashMode.strobe => '频闪中（${_freq.round()} Hz）',
                        _FlashMode.sos => 'SOS 求救信号',
                      },
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOn ? Colors.black87 : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // 模式选择
                    SegmentedButton<_FlashMode>(
                      segments: const [
                        ButtonSegment(value: _FlashMode.off, label: Text('关'), icon: Icon(Icons.flashlight_off_rounded, size: 18)),
                        ButtonSegment(value: _FlashMode.on, label: Text('常亮'), icon: Icon(Icons.light_mode_rounded, size: 18)),
                        ButtonSegment(value: _FlashMode.strobe, label: Text('频闪'), icon: Icon(Icons.flash_on_rounded, size: 18)),
                        ButtonSegment(value: _FlashMode.sos, label: Text('SOS'), icon: Icon(Icons.emergency_rounded, size: 18)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => _switchMode(s.first),
                    ),
                    // 频闪频率
                    if (_mode == _FlashMode.strobe) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text('频率'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _freq,
                              min: 1,
                              max: 12,
                              divisions: 11,
                              label: '${_freq.round()} Hz',
                              onChanged: (v) => setState(() => _freq = v),
                              onChangeEnd: (_) {
                                _patternTimer?.cancel();
                                _startStrobe();
                              },
                            ),
                          ),
                          Text('${_freq.round()} Hz'),
                        ],
                      ),
                    ],
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
