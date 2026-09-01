import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

/// CosyTool 应用根组件。
///
/// 负责全局主题（浅色/深色跟随系统）与应用入口。
class CosyToolApp extends StatelessWidget {
  const CosyToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
