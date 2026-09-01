import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/permissions.dart';
import '../../core/utils/platform_check.dart';
import '../../data/tools_registry.dart';
import '../../models/tool_info.dart';
import '../../shared/widgets/tool_page_scaffold.dart';
import '../../shared/widgets/unsupported_platform.dart';

/// 延迟拍照工具：倒计时后自动拍摄（仅移动端）。
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
  int _delay = 3; // 倒计时秒数
  int? _countdown;
  String? _capturedPath;

  @override
  void initState() {
    super.initState();
    if (PlatformCheck.hasCameraSupport) _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _initError = null;
    });
    try {
      final granted = await Permissions.requestCamera();
      if (!granted) throw Exception('未获得相机权限');
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('未检测到相机');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    for (var i = _delay; i > 0; i--) {
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
    setState(() => _countdown = null);
    try {
      final xfile = await _controller!.takePicture();
      final docs = await getApplicationDocumentsDirectory();
      final saved = File(
        '${docs.path}${Platform.pathSeparator}cosytool_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await saved.writeAsBytes(await xfile.readAsBytes());
      if (!mounted) return;
      setState(() => _capturedPath = saved.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍摄失败：$e')),
      );
    }
  }

  void _retake() {
    setState(() => _capturedPath = null);
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

    return Stack(
      alignment: Alignment.center,
      children: [
        // 预览或已拍照片
        if (_capturedPath != null)
          Positioned.fill(
            child: Image.file(
              File(_capturedPath!),
              fit: BoxFit.cover,
            ),
          )
        else if (_controller != null)
          Positioned.fill(
            child: CameraPreview(_controller!),
          )
        else
          const Center(child: CircularProgressIndicator()),

        // 倒计时遮罩
        if (_countdown != null)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),

        // 底部控制
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: _capturedPath != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _retake,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('重新拍摄'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('照片已保存：$_capturedPath')),
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('完成'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 延时选择
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in [3, 5, 10])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: Text('${d}s'),
                                selected: _delay == d,
                                onSelected: (_) => setState(() => _delay = d),
                                labelStyle: const TextStyle(color: Colors.white),
                                selectedColor: colorScheme.primary,
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 快门
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _shoot,
                        child: const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 34),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
