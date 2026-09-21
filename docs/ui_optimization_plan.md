# CosyTool 界面设计优化方案

> 以资深 UI 设计师视角，基于对当前代码（主题 / 外壳 / 首页 / 18 个工具页 / 组件）的完整勘察。
> 目标：在保持「轻量工具箱」定位与青蓝品牌基调不变的前提下，系统性提升视觉品质、层级秩序、跨端一致性与可访问性。

---

## 一、现状诊断

### 1.1 已具备的良好基础（保留项）

| 维度 | 现状 | 评价 |
|---|---|---|
| 品牌一致性 | 青蓝双色（#0E9F8F → #37B6C9）贯穿 Logo、卡片图标、波形、About | ✅ 识别度强，继续沿用 |
| 设计规范 | Material 3 + ColorScheme.fromSeed + surfaceContainer 分层色板 | ✅ 起点正确 |
| 响应式骨架 | 三档断点、桌面侧栏 / 移动抽屉、网格自适应、内容 maxWidth 1200 | ✅ 结构合理 |
| 工具辨识 | 每工具独立 accent 色 + 渐变图标块 | ✅ 增强查找效率 |
| 统一外壳 | ToolPageScaffold 统一工具页标题栏 | ✅ 一致性基础 |

### 1.2 核心问题（按优先级）

**P0 — 视觉层级与焦点缺失**
1. 18 个工具页几乎全部是「等宽卡片纵向堆叠」（`Center + ConstrainedBox + SingleChildScrollView + Column + Card`），无主次锚点。唯一例外是耳返 / 录音的中央大圆钮——这正是用户最容易感知的「主操作」。
2. 首页 17 张同构卡片（48px 渐变图标 + 名称 + 描述）平铺无分组，彩色噪音大，缺少信息架构。
3. 工具页内部无 Hero 操作区概念：主按钮（FilledButton 44px 高）与次级控件视觉权重几乎相同。

**P0 — 色彩系统不完整**
4. 语义色硬编码：成功 / 警告 / 危险（`0xFF2F9E6E`、`0xFFE85D5D`、`0xFF3AA6C9` 等）散落在 ear_monitor、decibel 等页，未纳入 colorScheme，深色模式下对比不可控。
5. 卡片 `surfaceContainerLow` 与页面背景 `#F6F7F9` 对比度过弱（ΔL 约 0.03），扁平到「无边界感」，长列表场景（设置页、文本阅读设置）易疲劳。
6. 17 个 accent 色与主题色（青蓝）风格不统一：`#F5C542`（手电筒）、`#F09B3A`（倒计时）等暖色与冷色品牌并存，首页观感杂乱。

**P1 — 排版与间距系统**
7. 说明文字大量使用 `bodySmall`（12px）+ `outline`/`onSurfaceVariant` 色，浅色背景对比度不足 4.5:1，且 12px 在桌面端偏小。
8. 垂直节奏单调：工具页统一 `padding 24 + 卡片间距 20`，无「块级分组」概念；标题与内容间距（4/8/12）在各页不一致。
9. 各工具页内容最大宽度不一致（560/640/680/760），宽屏下左对齐居中但两侧留白形态各异。
10. 数字场景已用 tabularFigures（✅），但大数字（分贝、计时）缺字号阶梯与强调方式。

**P1 — 交互与动效**
11. 微交互缺失：卡片无 hover 反馈（首页 ToolCard 桌面端仅 InkWell 涟漪）、无按压抬升、无数值动画（电平、计时数字跳变生硬）。
12. 页面切换只有 AnimatedSwitcher 220ms（✅），但工具页内部区块无过渡。
13. 所有反馈统一 SnackBar：操作成功 / 失败 / 提示混用同一通道，缺少轻重分级（如成功轻提示、失败对话框、表单内联错误）。

**P1 — 可访问性**
14. 部分 IconButton（AppBar 操作、列表尾随）触控目标 < 40px，移动端不达标（48dp 推荐）。
15. 无系统字号缩放适配（工具页固定高度卡片、固定文字 fontSize 多处）。
16. 语义标签缺失：图标按钮多无 tooltip（如侧边栏、部分操作钮）。

**P2 — 桌面端体验**
17. 无窗口菜单栏（File/Edit/View 习惯缺失）、无快捷键。
18. 侧边栏固定 236px + 内容居中，宽屏下内容区利用率一般（1200 上限内）。
19. About 页项目链接点击仅弹 SnackBar，未调起浏览器；「深色模式」抽屉项无实际功能（仅提示）。

---

## 二、设计系统（Design Tokens）

> 建议新建 `lib/core/theme/app_tokens.dart`，统一收敛色 / 间距 / 圆角 / 字号 / 动效，消灭硬编码。

### 2.1 品牌色（沿用，收敛为 Token）

| Token | 值 | 用途 |
|---|---|---|
| `brand.primary` | `#0E9F8F` | 主操作、选中态、品牌渐变起点 |
| `brand.secondary` | `#37B6C9` | 品牌渐变终点、强调 |
| `brand.gradient` | `primary → secondary`（左上→右下） | Logo、图标块、Hero |

### 2.2 语义色（新增，纳入 colorScheme）

| Token | 浅色 | 深色 | 用途 |
|---|---|---|---|
| `semantic.success` | `#2E9E6B` | `#6FD6A0` | 成功、达标、在线 |
| `semantic.warning` | `#E8973A` | `#F5B85E` | 警告、临界 |
| `semantic.danger` | `#E05B5B` | `#F08686` | 错误、超限、停止 |
| `semantic.info` | `#3A8FC9` | `#7DC1F2` | 信息、提示 |

> 做法：`ColorScheme.fromSeed(seedColor: ...)` 后手动覆盖 `error` 等扩展项，或直接定义 `AppSemanticColors` 映射表，由 ThemeExtension 注入，两套主题各一份，禁止页面硬编码。

### 2.3 间距（4pt 栅格）

| Token | 值 | 典型用途 |
|---|---|---|
| `space.xs` | 4 | 图标与文字间隙 |
| `space.sm` | 8 | 行内元素间距 |
| `space.md` | 16 | 卡片内边距、块内分组 |
| `space.lg` | 24 | 页面边距、区块间距 |
| `space.xl` | 32 | 大区块分隔、Hero 区 |
| `space.xxl` | 48 | 页面级留白 |

> 工具页统一：页面 `padding 24`（桌面 32）、卡片间距 `16`、卡片内 `20`、标题下 `12`。垂直节奏 = 4pt 数列，消除 10/14/18 等游离值。

### 2.4 圆角分级

| Token | 值 | 用途 |
|---|---|---|
| `radius.sm` | 8 | 小徽标、内嵌条 |
| `radius.md` | 12 | 按钮、输入框、SegmentedButton |
| `radius.lg` | 16 | 标准卡片 |
| `radius.xl` | 20 | Hero 卡、大操作区 |
| `radius.pill` | 999 | 圆形按钮、开关、chip |

### 2.5 字号阶梯（配合系统缩放）

| Token | 浅色 | 用途 |
|---|---|---|
| `type.display` | 32 / w800 | 首页大标题、大数字 |
| `type.title` | 20 / w700 | 工具页主标题、Hero 数值 |
| `type.section` | 16 / w700 | 卡片内区块标题 |
| `type.body` | 14 / w400 | 正文、说明（替代 bodySmall 提升可读性） |
| `type.caption` | 12 / w500 | 辅助说明、时间戳（限短文本） |
| `type.mono` | 13–14 | 数值、路径、代码（+ tabularFigures） |

> 正文说明从 12px 提到 13–14px；关键数字用 `display/title` 阶梯 + 品牌色，形成视觉焦点。

---

## 三、布局系统

### 3.1 统一工具页骨架（P0）

抽取 `ToolPageLayout` 组件（替代每页手写 `Center + ConstrainedBox + SingleChildScrollView`）：

- 内容宽度统一：窄屏 100%，宽屏 `min(720, 可用宽 − 48)`。
- 两档布局：
  - **窄屏（<600）**：单列滚动（现状）。
  - **宽屏（≥1000）**：宽内容页（设置、文本阅读）可切换为「左主区 + 右侧固定辅助面板」两栏（如文本阅读：左正文 / 右朗读控制），减少长滚动。
- 每页结构标准化：`Hero 区（可选）→ 配置区 → 操作区 → 信息/状态区 → 提示区`。

### 3.2 首页信息架构（P0）

- **分组**：17 个工具按类分组（音频 / 计时 / 文本 / 工具 / 存储），每组小标题（`type.section`），替代平铺大网格。
- **搜索**：桌面端顶部加搜索框（Ctrl/Cmd+F 聚焦），输入即过滤。
- **卡片视觉降噪**：accent 渐变图标块保留，但统一为「品牌渐变 + 工具 accent 小色点」或保留 accent 渐变但缩小为 44px、减弱阴影（blur 10→6，alpha 0.3→0.18），降低彩色噪音。

### 3.3 侧边栏（P1）

- 品牌区 Logo 复用 `AppLogo` 组件（统一 40px，三处 Logo 收敛为同一组件：侧栏 40 / 首页 48 / About 64 由参数控制）。
- 当前选中项增加左侧指示条（2px 品牌色圆角条）+ 悬停背景。
- 底部改为「设置 + 关于」固定项（当前设置混在工具列表里），并显示同步状态点（云端拉取后短暂高亮）。

---

## 四、组件升级

### 4.1 卡片体系（P0）

三层表面，替代单一 `surfaceContainerLow`：

| 层级 | 颜色 | 用法 |
|---|---|---|
| `surface.base` | 页面背景 | scaffold |
| `surface.card` | `surfaceContainerLow` + 1px `outlineVariant@50%` 描边 | 普通信息卡 |
| `surface.hero` | 品牌渐变底 / `primaryContainer` 底 | 主操作卡（耳返、录音、开始按钮） |

- 卡片默认无阴影（保持轻量），hover 时（桌面）`elevation 1 + 微抬升 1px`，通过统一的 `HoverCard` 封装。
- 统一 `Radius.lg`，特殊场景（Hero）用 `xl`。

### 4.2 Hero 操作区（P0）

新增 `HeroActionCard` 组件：大圆钮 / 大按钮 + 状态标题 + 副文案 + 可选进度。

- 耳返：保留 132px 大圆钮，增加「开启后按钮外圈呼吸光环动画」。
- 录音：同类处理（大圆钮 + 计时）。
- 其余工具页：主操作按钮提升为「整卡可点」Hero 区（如倒计时：中央大数字 + 下方开始/暂停），让每个工具页有一个明确视觉焦点。

### 4.3 状态与反馈（P1）

- **轻提示**：保留 SnackBar（成功类，2s 自动消失）。
- **强反馈**：失败 / 需确认 → 统一 `AppDialog`（品牌化 AlertDialog，圆角 20）。
- **内联错误**：表单校验错误显示在字段下方（errorText），不弹窗打断。
- **空状态**：统一 `EmptyState`（图标 + 标题 + 说明 + 可选行动作），替换各页散落的「暂无…」文本（如文本阅读书库、云端文件空目录、数据文件夹）。
- **加载**：列表加载用骨架屏（shimmer 风格，`surfaceContainerHighest` 脉动），按钮内 loading 保持现有 spinner。

### 4.4 数值动画（P1）

- 电平 / 分贝 / 计时数字用 `TweenAnimationBuilder` 或 `AnimatedSwitcher` 过渡（100–200ms easeOut），消除跳变。
- 波形 / 环形进度（倒计时、番茄钟）用隐式动画平滑推进。

### 4.5 桌面控件（P2）

- 设置页「打开文件夹」「复制路径」等用 `OutlinedButton` 统一；文本选择用 `SelectableText`（阅读页已用 ✅）。
- 宽输入（文本工具、云端文件编辑）在桌面端自动加 `TextField` 等宽字体 + 行号（文本工具页）。

---

## 五、动效规范

| 场景 | 建议 |
|---|---|
| 页面切换 | 保留 AnimatedSwitcher 220ms easeOut；移动端路由过渡保持平台默认 |
| 卡片 hover（桌面） | 抬升 2px + 阴影 0→1 + 图标微缩放 1.02（120ms） |
| 按压 | 默认涟漪外，主按钮按压 scale 0.98（80ms） |
| 数值变化 | 100–200ms Tween |
| 开关 / 分段 | 使用 Material 内置动效，不额外定制 |
| 减少动效 | 尊重系统「减少动态效果」设置（`MediaQuery.disableAnimations`） |

> 动效统一封装：`Motion` 工具类（`Motion.quick()` / `Motion.standard()` 曲线与时长常量），禁止页面散写 Duration。

---

## 六、可访问性（P0/P1）

1. **对比度**：正文 ≥ 4.5:1、大标题 ≥ 3:1；`onSurfaceVariant` 说明文字提到 13px+；`outline` 色仅用于装饰性元素。
2. **触控目标**：移动端所有 IconButton / 图标操作 ≥ 44–48px（`IconButton` 加 `visualDensity` 或 constraints），列表尾随操作保留紧凑但外扩 hit area。
3. **语义**：AppBar 操作、图标按钮补 `tooltip`；分组网格用 `Semantics(label: '工具：$name')`。
4. **字号缩放**：工具页布局改用 `MediaQuery.textScalerOf` 自适应（卡片高度不写死、Text 不固定 fontSize 的场景用 style 阶梯）。
5. **焦点管理（桌面）**：支持 Tab 遍历 + 可见焦点环（`focusColor` 统一品牌色）。
6. **动效开关**：尊重系统 reduce-motion。

---

## 七、主题强化（P1）

1. **深色模式细化**：页面背景 `#111418`，卡片 `surfaceContainerLow` 之上加 `#1D2226` 分层；侧栏 `#171A1F` 保留；所有语义色提供深色变体。
2. **滚动条**：桌面端统一细滚动条（`ScrollbarTheme`：圆角 4px、thumb `outlineVariant`）。
3. **选择器**：`SegmentedButton`、`Switch`、`Slider` 走 colorScheme，禁止页面内自定义颜色。
4. **主题切换入口**：抽屉「深色模式」实现真实切换（`ThemeMode.system/light/dark` + shared_preferences 持久化），补齐缺口。

---

## 八、桌面端增强（P2）

| 项 | 方案 |
|---|---|
| 菜单栏 | `flutter_window` 注入原生菜单（文件：设置 / 关于 / 退出；视图：主题切换）或纯 Flutter `MenuBar` |
| 快捷键 | 全局：Ctrl/Cmd+F 首页搜索、Ctrl/Cmd+, 设置、Ctrl/Cmd+K 工具切换（命令面板） |
| 命令面板 | 桌面端 Ctrl/Cmd+K 弹出工具搜索面板（复用首页搜索逻辑） |
| 窗口记忆 | 记录窗口尺寸 / 位置 / 状态（shared_preferences） |
| 拖放 | 文本阅读支持把 .txt 拖进窗口直接打开 |
| 托盘 | 可选：最小化到系统托盘（后续） |

---

## 九、分阶段实施路线

### P0（视觉与信息架构，优先落地）
1. 设计 Token 文件（色 / 间距 / 圆角 / 字号 / 动效）接入主题
2. 卡片体系三表面 + 描边 + HoverCard
3. HeroActionCard 应用到耳返 / 录音 / 倒计时 / 番茄钟
4. 首页分组 + 搜索（桌面）+ 卡片降噪
5. 统一工具页骨架 ToolPageLayout（内容宽度统一）

### P1（体验完整度）
6. 语义色 Token 替换硬编码（耳返 / 分贝 / 倒计时等）
7. 状态反馈分级（AppDialog / EmptyState / 骨架屏）
8. 数值动画 + 微交互（hover / 按压）
9. 可访问性：对比度、触控目标、语义、字号缩放
10. 深色模式细化 + 主题切换真实化
11. 统一 Logo 组件与侧栏指示条

### P2（桌面端与长线）
12. 菜单栏 / 快捷键 / 命令面板 / 窗口记忆 / 拖放
13. About 链接真实打开浏览器
14. 两栏宽屏布局（设置 / 文本阅读）

---

## 十、验收标准

- 浅 / 深两套主题下，所有页面正文对比度 ≥ 4.5:1，无硬编码语义色残留（grep 校验）
- 首页与 18 个工具页均能识别出唯一视觉焦点（Hero）
- 桌面端 1000–1920px 宽度下内容宽度统一、无溢出；移动端触控目标 ≥ 44px
- 动效遵循 Motion 工具类常量，系统 reduce-motion 下禁用
- 主题切换真实生效并持久化
- `flutter analyze` 0 issues；桌面端构建通过、启动正常

---

*文档定位：方案评审稿。P0 阶段经确认后即可按此实施，实施顺序与「通用组件先行、页面逐一接入」原则同步推进。*
