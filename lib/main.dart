import 'package:flutter/material.dart';

import 'app.dart';
import 'core/utils/window_memory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 桌面端恢复并记忆窗口尺寸 / 位置
  await WindowMemory.init();
  runApp(const CosyToolApp());
}
