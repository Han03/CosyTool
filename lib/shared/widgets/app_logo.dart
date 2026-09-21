import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 统一品牌 Logo：品牌绿渐变圆角方块 + 白色 handyman 图标。
///
/// 侧边栏、首页、About、工具页标题统一使用该组件，[size] 控制整体尺寸。
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.iconSize});

  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.primary, BrandColors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primary.withValues(alpha: 0.22),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.handyman_rounded,
        color: BrandColors.onPrimary,
        size: iconSize ?? size * 0.55,
      ),
    );
  }
}
