import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/tool_info.dart';

/// 工具页面的统一外壳。
///
/// 所有工具页面复用该组件，保证标题栏风格一致：
/// 左侧为品牌绿图标 + 名称，右侧可挂载操作按钮。
class ToolPageScaffold extends StatelessWidget {
  const ToolPageScaffold({
    super.key,
    required this.tool,
    required this.child,
    this.actions = const [],
  });

  final ToolInfo tool;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BrandColors.primary, BrandColors.secondary],
                ),
              ),
              child: Icon(tool.icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Text(tool.name),
          ],
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}
