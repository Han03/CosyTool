import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 统一对话框：品牌化 AlertDialog（圆角 20、可选语义图标色）。
///
/// 用于失败反馈 / 需确认的操作；轻提示仍用 SnackBar。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  IconData? icon,
  Color? iconColor,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      icon: icon == null
          ? null
          : Icon(icon, size: 36, color: iconColor ?? Theme.of(ctx).colorScheme.primary),
      title: Text(title),
      content: content,
      actions: actions,
    ),
  );
}
