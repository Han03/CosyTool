import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// 屏幕类型。
enum ScreenType { mobile, tablet, desktop }

/// 响应式工具：根据可用宽度返回对应的屏幕类型。
///
/// - mobile  (< 600)   ：手机，抽屉 + 网格
/// - tablet  (600-999) ：平板/窄桌面，紧凑导航栏
/// - desktop (>= 1000) ：桌面，完整导航栏
class Responsive {
  Responsive._();

  static ScreenType of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.breakpointDesktop) return ScreenType.desktop;
    if (width >= AppConstants.breakpointMobile) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) => of(context) == ScreenType.mobile;

  static bool isTablet(BuildContext context) => of(context) == ScreenType.tablet;

  static bool isDesktop(BuildContext context) => of(context) == ScreenType.desktop;

  /// 根据屏幕宽度估算网格列数。
  static int gridColumns(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    switch (of(context)) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  /// 桌面端内容区的最大宽度，避免超宽屏内容过散。
  static const double maxContentWidth = 1200;
}
