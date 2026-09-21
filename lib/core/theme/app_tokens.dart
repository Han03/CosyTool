import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）。
///
/// 颜色以品牌绿（#0E9F8F）为主色调，收敛全局语义色 / 间距 / 圆角 / 动效，
/// 禁止页面散写魔法值（颜色、间距、圆角、时长）。
class AppTokens {
  AppTokens._();
}

/// 品牌色（图标 / Logo / 主操作的统一渐变基调）。
class BrandColors {
  BrandColors._();

  static const Color primary = Color(0xFF0E9F8F);
  static const Color secondary = Color(0xFF37B6C9);
  static const Color onPrimary = Colors.white;
}

/// 语义色：浅色 / 深色两套，经 [AppSemanticColors] 注入主题。
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF2E9E6B),
    onSuccess: Colors.white,
    successContainer: Color(0xFFD3F2E2),
    onSuccessContainer: Color(0xFF0B3B26),
    warning: Color(0xFFE08A2E),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFBE8CD),
    onWarningContainer: Color(0xFF4A2C08),
    danger: Color(0xFFE05B5B),
    onDanger: Colors.white,
    dangerContainer: Color(0xFFFBD9D9),
    onDangerContainer: Color(0xFF4A0E0E),
    info: Color(0xFF3A8FC9),
    onInfo: Colors.white,
    infoContainer: Color(0xFFD7EBFA),
    onInfoContainer: Color(0xFF0C2B44),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF6FD6A0),
    onSuccess: Color(0xFF06291A),
    successContainer: Color(0xFF1E4A35),
    onSuccessContainer: Color(0xFFB0E8C8),
    warning: Color(0xFFF5B85E),
    onWarning: Color(0xFF40240A),
    warningContainer: Color(0xFF5C3A14),
    onWarningContainer: Color(0xFFFBD9A8),
    danger: Color(0xFFF08686),
    onDanger: Color(0xFF4A1010),
    dangerContainer: Color(0xFF632424),
    onDangerContainer: Color(0xFFF7C2C2),
    info: Color(0xFF7DC1F2),
    onInfo: Color(0xFF0B2A42),
    infoContainer: Color(0xFF1D4A70),
    onInfoContainer: Color(0xFFC2E2FA),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: lc(success, other.success),
      onSuccess: lc(onSuccess, other.onSuccess),
      successContainer: lc(successContainer, other.successContainer),
      onSuccessContainer: lc(onSuccessContainer, other.onSuccessContainer),
      warning: lc(warning, other.warning),
      onWarning: lc(onWarning, other.onWarning),
      warningContainer: lc(warningContainer, other.warningContainer),
      onWarningContainer: lc(onWarningContainer, other.onWarningContainer),
      danger: lc(danger, other.danger),
      onDanger: lc(onDanger, other.onDanger),
      dangerContainer: lc(dangerContainer, other.dangerContainer),
      onDangerContainer: lc(onDangerContainer, other.onDangerContainer),
      info: lc(info, other.info),
      onInfo: lc(onInfo, other.onInfo),
      infoContainer: lc(infoContainer, other.infoContainer),
      onInfoContainer: lc(onInfoContainer, other.onInfoContainer),
    );
  }
}

/// 间距（4pt 栅格）。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// 圆角分级。
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// 动效时长与曲线（遵循 Motion 规范）。
class AppMotion {
  AppMotion._();

  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
}

/// 工具页内容宽度：窄屏 100%，宽屏统一 min(720, 可用宽 - 48)。
const double kToolContentWidth = 720;

/// 宽屏工具页（两栏布局）内容宽度。
const double kToolContentWidthWide = 1100;
