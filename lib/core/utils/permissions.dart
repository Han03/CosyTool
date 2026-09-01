import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限请求工具。
class Permissions {
  Permissions._();

  /// 请求麦克风权限，返回是否已授权。
  /// 桌面端通常无需运行时授权，直接视为已授予。
  static Future<bool> requestMic() async {
    if (kIsWeb) return true;
    if (!PlatformCheckInternal.isDesktop) {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// 请求相机权限，返回是否已授权。
  static Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }
}

/// 内部辅助，避免与 UI 层耦合。
class PlatformCheckInternal {
  PlatformCheckInternal._();
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
