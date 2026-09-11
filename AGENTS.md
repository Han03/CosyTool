# AGENTS.md

## 构建约定（用户明确要求，每次任务完成后必须执行）

- **每次任务完成后，必须构建最新版桌面端**：
  `flutter build windows --release`（工作目录：仓库根目录）
  产物：`build\windows\x64\runner\Release\cosy_tool.exe`
- Windows 环境变量模板：
  `$env:Path += ";C:\flutter\bin"`
  `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"`
  `$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"`
- 推送 GitHub 需用 `git -c http.version=HTTP/1.1 push origin main`（HTTP/2 会被 RST 阻断）

## 项目结构

- Flutter 工具箱（CosyTool），手机/桌面自适应。所有工具在 `lib/features/<name>/` 下，登记于 `lib/data/tools_registry.dart`（新增工具 = 新页面 + 注册一条 ToolInfo）。
- 页面统一使用 `lib/shared/widgets/tool_page_scaffold.dart`，内容区 `ConstrainedBox(maxWidth 560-640) + SingleChildScrollView` 居中窄栏。
- 真机调试：`adb install -r build\app\outputs\flutter-apk\app-release.apk`（包名 com.cosytool.cosy_tool）。
- 硬件类工具（相机/手电筒等）桌面端走 UnsupportedPlatformView 友好提示，不得崩溃。
