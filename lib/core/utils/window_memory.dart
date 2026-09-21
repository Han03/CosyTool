import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端窗口记忆：保存 / 恢复窗口尺寸与位置（仅桌面平台生效）。
class WindowMemory extends WindowListener {
  WindowMemory._();

  static const double _defaultWidth = 1180;
  static const double _defaultHeight = 760;

  static const String _kWidth = 'window_width';
  static const String _kHeight = 'window_height';
  static const String _kX = 'window_x';
  static const String _kY = 'window_y';

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// 应用启动时初始化窗口管理器、恢复上次的尺寸与位置，并监听变化保存。
  static Future<void> init() async {
    if (!_isDesktop) return;
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    final width = prefs.getDouble(_kWidth) ?? _defaultWidth;
    final height = prefs.getDouble(_kHeight) ?? _defaultHeight;
    final x = prefs.getDouble(_kX);
    final y = prefs.getDouble(_kY);

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(width, height),
        minimumSize: const Size(900, 600),
        center: x == null || y == null,
      ),
      () async {
        if (x != null && y != null) {
          await windowManager.setPosition(Offset(x, y));
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(WindowMemory._());
  }

  @override
  void onWindowResized() => _persistGeometry();

  @override
  void onWindowMoved() => _persistGeometry();

  Future<void> _persistGeometry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      await prefs.setDouble(_kWidth, size.width);
      await prefs.setDouble(_kHeight, size.height);
      await prefs.setDouble(_kX, pos.dx);
      await prefs.setDouble(_kY, pos.dy);
    } catch (_) {
      // 保存失败不影响运行
    }
  }
}
