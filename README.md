# CosyTool · 轻量工具箱

基于 **Flutter** 的跨平台常用小工具合集。一套代码，自适应手机 / 平板 / 桌面端。

## ✨ 功能

| 工具 | 说明 | 平台 |
| --- | --- | --- |
| 🎙️ 录音机 | 高清录音（AAC/M4A）、回放、录音管理 | 全平台 |
| 📊 分贝测试 | 实时音量测量、趋势曲线、最值统计 | 全平台 |
| 📷 延迟拍照 | 倒计时后自动拍摄 | Android / iOS |
| ⏱️ 秒表 | 计时、分段记录 | 全平台 |
| ⏳ 倒计时 | 预设 + 自定义时长、圆环进度 | 全平台 |
| 🍅 番茄钟 | 专注 / 短休 / 长休循环 | 全平台 |
| 🎲 骰子 | 1-3 个骰子滚动动画 | 全平台 |
| 🔀 随机数 | 区间随机、去重、复制 | 全平台 |
| 🔄 单位换算 | 长度 / 重量 / 温度 / 面积 / 体积 / 速度 / 时间 / 数据 | 全平台 |
| 🔦 手电筒 | 一键闪光灯照明 | Android / iOS |
| 〰️ 二维码 | 文本生成二维码并保存为图片 | 全平台 |

> 全平台 = Android / iOS / Windows / macOS / Linux / Web。
> 手电筒、延迟拍照依赖移动端硬件，桌面端会给出友好提示。

## 🛠️ 技术栈

- Flutter 3.x / Dart 3.x，Material 3
- 响应式布局：`<600px` 抽屉 + 网格，`>=1000px` 侧边导航
- 关键依赖：`record`（录音/电平）、`audioplayers`（回放）、`camera`（相机）、`torch_light`（手电筒）、`qr_flutter`（二维码）、`permission_handler`（权限）、`path_provider`（文件目录）

## 📁 项目结构

```
lib/
├── main.dart                  # 入口
├── app.dart                   # 应用根组件（主题 + 路由）
├── core/
│   ├── constants/             # 应用常量 / 断点
│   ├── theme/                 # Material 3 主题（浅色/深色）
│   ├── responsive/            # 响应式断点工具
│   └── utils/                 # 平台判断、权限请求
├── models/
│   └── tool_info.dart         # 工具元信息模型
├── data/
│   └── tools_registry.dart    # 工具注册表（新增工具入口）
├── shared/widgets/            # 工具卡片、页面外壳、平台占位等
└── features/                  # 每个工具一个独立模块
    ├── home/                  # 响应式外壳 + 首页网格
    ├── recorder/  decibel/  camera_timer/
    ├── stopwatch/ countdown/  pomodoro/
    ├── dice/  random_tool/  converter/
    └── flashlight/  qrcode/  about/
```

**新增工具**：在 `features/` 下新建页面组件，然后在 `data/tools_registry.dart` 注册一条 `ToolInfo` 即可，首页 / 抽屉 / 侧边栏会自动接入。

## 🚀 运行

```bash
# 安装依赖
flutter pub get

# 运行（桌面端）
flutter run -d windows

# 运行（Android）
flutter run -d <device-id>

# 静态检查
flutter analyze

# 测试
flutter test
```

## 📝 备注

- 分贝数值为相对参考值，未做设备级校准，不同设备存在差异。
- Android 需授予录音 / 相机运行时权限；权限在 `AndroidManifest.xml` 已声明。

## 📄 License

MIT
