import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/permissions.dart';
import '../../core/utils/platform_check.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../../shared/widgets/unsupported_platform.dart';

/// 延迟拍照工具：倒计时后自动拍摄，支持前后摄切换、闪光灯、连拍并保存到相册。
class CameraTimerPage extends StatefulWidget {
  const CameraTimerPage({super.key});

  @override
  State<CameraTimerPage> createState() => _CameraTimerPageState();
}

class _CameraTimerPageState extends State<CameraTimerPage> {
  static final ToolInfo _tool = ToolRegistry.of('camera_timer');

  CameraController? _controller;
  bool _initializing = true;
  String? _initError;
  CameraLensDirection _lens = CameraLensDirection.back;
  FlashMode _flash = FlashMode.off;
  int _delay = 3; // 倒计时秒数
  int _burst = 1; // 连拍张数
  int? _countdown;
  bool _capturing = false;
  List<String> _capturedPaths = const [];
  bool _savingGallery = false;

  @override
  void initState() {
    super.initState();
    if (PlatformCheck.hasCameraSupport) _initCamera();
  }

  Future<void> _initCamera({CameraLensDirection? lens}) async {
    setState(() {
      _initializing = true;
      _initError = null;
    });
    try {
      final granted = await Permissions.requestCamera();
      if (!granted) throw Exception('未获得相机权限');
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('未检测到相机');
      final target = lens ?? _lens;
      final matched = cameras.where((c) => c.lensDirection == target).toList();
      final chosen = matched.isNotEmpty ? matched.first : cameras.first;
      final controller = CameraController(
        chosen,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // 应用闪光模式（若设备支持）
      try {
        await controller.setFlashMode(_flash);
      } catch (_) {}
      setState(() {
        _lens = chosen.lensDirection;
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = '$e';
        _initializing = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    final old = _controller;
    setState(() => _controller = null);
    await old?.dispose();
    await _initCamera(lens: _lens == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back);
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {}
    setState(() => _flash = next);
  }

  String get _flashLabel => switch (_flash) {
        FlashMode.off => '关',
        FlashMode.auto => '自动',
        _ => '常亮',
      };

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    if (_controller == null || !_controller!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    // 倒计时
    for (var i = _delay; i > 0; i--) {
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    setState(() => _countdown = null);
    final docs = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${docs.path}${Platform.pathSeparator}photos');
    if (!await photoDir.exists()) await photoDir.create(recursive: true);
    final saved = <String>[];
    try {
      for (var n = 0; n < _burst; n++) {
        final xfile = await _controller!.takePicture();
        final bytes = await xfile.readAsBytes();
        final file = File(
          '${photoDir.path}${Platform.pathSeparator}cosytool_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(bytes);
        saved.add(file.path);
        // 连拍间隔
        if (n < _burst - 1) await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (!mounted) return;
      setState(() {
        _capturedPaths = saved;
        _capturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_burst > 1 ? '已拍摄 $_burst 张' : '拍摄完成')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍摄失败：$e')),
      );
    }
  }

  Future<void> _saveToGallery() async {
    if (_capturedPaths.isEmpty) return;
    setState(() => _savingGallery = true);
    var ok = 0;
    try {
      for (final p in _capturedPaths) {
        final bytes = await File(p).readAsBytes();
        await _putImage(bytes);
        ok++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 $ok 张到系统相册')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存相册失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _savingGallery = false);
    }
  }

  Future<void> _putImage(Uint8List bytes) async {
    if (await Gal.hasAccess()) {
      await Gal.putImageBytes(bytes);
      return;
    }
    await Gal.requestAccess();
    await Gal.putImageBytes(bytes);
  }

  void _retake() {
    setState(() => _capturedPaths = const []);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCheck.hasCameraSupport) {
      return ToolPageScaffold(
        tool: _tool,
        child: UnsupportedPlatformView(
          toolName: _tool.name,
          icon: _tool.icon,
        ),
      );
    }
    return ToolPageScaffold(
      tool: _tool,
      child: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              const Text('相机初始化失败'),
              const SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasPhoto = _capturedPaths.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 预览或已拍照片
        if (hasPhoto)
          Positioned.fill(
            child: Image.file(
              File(_capturedPaths.last),
              fit: BoxFit.cover,
            ),
          )
        else if (_controller != null)
          Positioned.fill(
            child: CameraPreview(_controller!),
          )
        else
          const Center(child: CircularProgressIndicator()),

        // 倒计时遮罩 + 圆环
        if (_countdown != null)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: 1 - (_countdown! - 1) / _delay,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 110,
                    fontWeight: FontWeight.w300,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

        // 顶部工具按钮（非拍摄时）
        if (!hasPhoto && _countdown == null && !_capturing)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _GlassButton(
                  icon: _lens == CameraLensDirection.back
                      ? Icons.camera_front_rounded
                      : Icons.camera_rear_rounded,
                  label: _lens == CameraLensDirection.back ? '后置' : '前置',
                  onTap: _switchCamera,
                ),
                const Spacer(),
                _GlassButton(
                  icon: switch (_flash) {
                    FlashMode.off => Icons.flash_off_rounded,
                    FlashMode.auto => Icons.flash_auto_rounded,
                    _ => Icons.flash_on_rounded,
                  },
                  label: _flashLabel,
                  onTap: _cycleFlash,
                ),
              ],
            ),
          ),

        // 底部控制
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: hasPhoto
              ? _buildPhotoActions()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_countdown == null && !_capturing) ...[
                      // 延时选择
                      _ChipGroup(
                        values: const [3, 5, 10],
                        selected: _delay,
                        label: (v) => '${v}s',
                        onSelect: (v) => setState(() => _delay = v),
                      ),
                      const SizedBox(height: 8),
                      // 连拍选择
                      _ChipGroup(
                        values: const [1, 3, 5],
                        selected: _burst,
                        label: (v) => v == 1 ? '单张' : '连拍 $v 张',
                        onSelect: (v) => setState(() => _burst = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 快门
                    Material(
                      color: _capturing ? colorScheme.surfaceContainerHighest : Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _capturing ? null : _shoot,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _capturing
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 34),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPhotoActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _retake,
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text('重新拍摄'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _savingGallery ? null : _saveToGallery,
          icon: _savingGallery
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library_rounded),
          label: Text(_savingGallery ? '保存中…' : '保存到相册'),
        ),
      ],
    );
  }
}

/// 半透明工具按钮（覆盖在相机预览上）。
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 相机上的选项组。
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  final List<int> values;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (_) => onSelect(v),
                labelStyle: TextStyle(
                  color: selected == v ? Colors.black87 : Colors.white,
                  fontSize: 12,
                ),
                selectedColor: Colors.white,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
        ],
      ),
    );
  }
}
