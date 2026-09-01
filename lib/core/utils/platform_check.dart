import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 平台能力判断工具。
///
/// 部分工具（相机、手电筒等）依赖移动端硬件，在桌面端不可用，
/// 通过这些方法统一判断并在 UI 层给出友好提示。
class PlatformCheck {
  PlatformCheck._();

  /// 当前是否为移动端（Android / iOS）。
  static bool get isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 当前是否为桌面端（Windows / macOS / Linux）。
  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// 当前是否支持相机。
  static bool get hasCameraSupport => isMobile;

  /// 当前是否支持手电筒。
  static bool get hasFlashlightSupport => isMobile;

  /// 当前是否支持麦克风录音。桌面端（Windows/macOS/Linux）也可录音。
  static bool get hasMicSupport => !kIsWeb;

  /// 平台名称（用于展示）。
  static String get platformLabel {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return defaultTargetPlatform.name;
  }
}
