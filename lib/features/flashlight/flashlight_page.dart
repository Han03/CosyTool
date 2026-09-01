import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';

import '../../core/utils/platform_check.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../../shared/widgets/unsupported_platform.dart';

/// 手电筒工具：调用闪光灯照明（仅移动端）。
class FlashlightPage extends StatefulWidget {
  const FlashlightPage({super.key});

  @override
  State<FlashlightPage> createState() => _FlashlightPageState();
}

class _FlashlightPageState extends State<FlashlightPage> {
  static final ToolInfo _tool = ToolRegistry.of('flashlight');

  bool _on = false;
  bool _busy = false;
  bool? _available;

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

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_on) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      if (!mounted) return;
      setState(() => _on = !_on);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (_on) TorchLight.disableTorch();
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

    return ToolPageScaffold(
      tool: _tool,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: _on ? const Color(0xFFFDF3D7) : colorScheme.surface,
        child: SafeArea(
          child: Center(
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
                    color: _on ? const Color(0xFFF5C542) : colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    elevation: _on ? 12 : 3,
                    shadowColor: const Color(0xFFF5C542).withValues(alpha: 0.5),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggle,
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Icon(
                          _on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          size: 72,
                          color: _on ? Colors.black87 : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _on ? '点击关闭手电筒' : '点击开启手电筒',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _on ? Colors.black87 : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
