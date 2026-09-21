import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/home/home_shell.dart';

/// CosyTool 应用根组件。
///
/// 负责全局主题（浅色 / 深色 / 跟随系统，持久化）与应用入口。
class CosyToolApp extends StatefulWidget {
  const CosyToolApp({super.key, this.themeController});

  /// 可注入的控制器（测试用）；为空时内部创建。
  final ThemeController? themeController;

  @override
  State<CosyToolApp> createState() => _CosyToolAppState();
}

class _CosyToolAppState extends State<CosyToolApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
    _themeController.load();
  }

  @override
  void dispose() {
    if (widget.themeController == null) _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: HomeShell(themeController: _themeController),
        );
      },
    );
  }
}
