# CosyTool 耳返工具 · 极致低延迟方案设计

> 版本：v1.0 · 2026-09-11 · 状态：Phase 1 已实现

## 1. 目标与核心指标

| 指标 | 目标 | 说明 |
|---|---|---|
| 端到端监听延迟 | **约 20-60ms（真机验证）** | 受插件采集周期 1024 帧（48kHz 下 21.3ms）约束；远优于 Dart 管线 100-300ms |
| 防啸叫 | AEC 支持 | 扬声器外放时消除声学回授（howling） |
| 实时电平反馈 | 音量 dB + 波形 | 演唱/发言时可见自身音量 |
| 平台覆盖 | Android / iOS / Win / macOS / Linux / Web | 与 CosyTool 跨平台目标一致 |

## 2. 为什么"极致低延迟"必须走原生回环

### 2.1 反面方案：纯 Dart 音频管线

常规做法是 `record.startStream()` 把 PCM 流回调到 Dart，再用 `audioplayers` 低延迟模式播放：

```
麦克风 → record 原生采集 → Dart Stream 回调 → 事件循环调度 → audioplayers 缓冲 → 耳机
```

延迟分解（实测经验值）：

| 环节 | 延迟 |
|---|---|
| record PCM 流回调 + Dart 调度 | 5-20ms |
| audioplayers 播放缓冲（Android SoundPool/AAudio） | 50-150ms |
| 设备输出缓冲 | 2-5ms |
| **合计** | **100-300ms** |

结论：100ms+ 的延迟在唱歌时能明显听到"自己的回声"，完全无法作为监听使用。

### 2.2 正确方案：原生双工回环（Native Duplex Loopback）

基于 **flutter_recorder 2.0.3**（miniaudio C 后端，FFI 接入）：

```
麦克风 → miniaudio 采集（Android OpenSL/AAudio、Windows WASAPI、iOS AVAudioSession）
       → 原生回环：PCM 直接送输出设备（耳机），全程 native C++，约 20-60ms（受 1024 帧周期约束）
       → AEC（SpeexDSP）：以回环信号为远端参考，消除啸叫
       → Dart 侧仅消费控制/指标（音量、波形、FFT、事件），不参与音频搬运
```

**关键原则：音频数据流不经过 Dart 层。** Dart 只做 UI 控制与可视化，回环路径完全在 native 内完成，这是低延迟的根基。

## 3. 延迟预算

| 环节 | 预算（真机实测/推导） |
|---|---|
| 麦克风采集缓冲（BUFFER_SIZE=1024 帧 @48kHz） | ~21ms |
| 原生回环分发（duplex 环形缓冲 + 内存拷贝） | ~1-5ms |
| 耳机输出缓冲（OpenSL 低延迟路径） | 5-30ms |
| **合计** | **约 20-60ms** |

> 注：flutter_recorder 2.0.3 的采集周期固定为 1024 帧，因此原生回环存在约 21ms 的下限；
> 若要逼近 10-15ms，需 fork 插件将 `BUFFER_SIZE` 降至 240-480 帧，或改用 AAudio 独占低延迟流（见 §7）。

Android 硬件能力参考：
- `android.hardware.audio.low_latency`：输出连续延迟 ≤ 45ms
- `android.hardware.audio.pro`：往返延迟 ≤ 20ms（满足专业监听）

## 3.1 真机验证结论（OPPO PHK110 / Android 13+，2026-09-11）

| 项 | 结论 |
|---|---|
| 原生回环可用性 | **仅「语音通信」预置可用**：该预置强制 miniaudio 走 **OpenSL ES** 后端（单引擎双工、环形缓冲合并），duplex 回环与能量计算均正常 |
| AAudio 双工缺陷 | 「原始 / 语音识别」预置走 **AAudio** 后端：双工被拆成独立输入/输出流，`data_callback` 的 `pInput`/`pOutput` 互斥为 NULL，**原生回环静音、能量恒为 -100**（`getVolumeDb` 不更新） |
| 延迟测试（声学脉冲法） | 实测 **309ms**（媒体通路 deep-buffer 输出 281ms + 采集路径）；能量检测阈值 >-38dB，15ms 轮询 |
| 延迟测试前置条件 | ① 媒体音量必须足够大（adb 音量 0-160，`cmd media_session volume --set` 在 ColorOS 失效，需音量键）；② 需「语音通信」预置；③ 需断开蓝牙（否则脉冲走 A2DP） |
| 媒体音量坑 | 本机 `cmd media_session volume --stream 3 --set 150` 不生效（恒 0/160），音量键 keyevent 24 正常 |

## 4. 功能设计

### Phase 1（本次交付）

| 功能 | 实现 |
|---|---|
| 监听开关 | `Recorder.setLoopback(enable)` 原生回环启停 |
| AEC 防啸叫 | `filters.echoCancellationFilter.activate()`（SpeexDSP，filterLength 150ms 可调） |
| Android 输入预置 | `AndroidInputPreset`：语音通信（硬件 AEC/AGC）/ 原始 / 语音识别 / 摄像机 |
| 采样率 | init 时选择 44.1kHz / 48kHz（miniaudio 自动重采样） |
| 实时电平 | `getVolumeDb()` + 波形（`audioVisualizationEvents`，256 点，仅 f32le 生效） |
| 设备通知 | `deviceNotificationEvents`：耳机插拔 / 路由变化 / 系统中断提示 |
| 延迟测试 | 声学脉冲法：外放 1kHz 脉冲（DeviceFileSource + lowLatency）→ `getVolumeDb` 轮询检测 → 实测往返延迟（需「语音通信」预置 + 媒体音量 + 无蓝牙） |
| 使用引导 | 有线耳机推荐、蓝牙延迟警示（100-300ms 不适合监听）、非语音通信预置的局限提示 |

### Phase 2（后续演进）

- DSP 效果链：混响 / 均衡（基于 `uint8ListStream` PCM + 滤波器）
- 自动增益（AutoGain filter，实验性）

### Phase 3（后续演进）

- 伴奏混音：flutter_soloud 播放伴奏，`feedPlaybackData()` 供 AEC 参考（Mode B），实现完整 K 歌场景
- 双人合唱 / 网络传输

## 5. 风险与应对

| 风险 | 应对 |
|---|---|
| 外放啸叫 | 默认开启 AEC；UI 提示使用耳机 |
| 蓝牙耳机高延迟 | 首页警示"蓝牙 100-300ms，监听请用有线耳机" |
| 设备热插拔 | 监听 `deviceNotificationEvents`，rerouted 时提示 |
| 回环叠加录音 | 设计说明：耳返开启时录音文件天然含监听信号，属正常行为 |
| 多实例冲突 | Recorder 为单例（native 唯一实例），页面退出时 `deinit()` 释放 |

## 6. 验证方案（真机：OPPO PHK110 / Android 13+）

1. 开启耳返（语音通信预置）→ 戴耳机可听到自身声音，无回声延迟感（~20-60ms）
2. 音量表随说话实时跳动（约 -100dB 静音 → -30~-60dB 说话），波形刷新
3. 拔插耳机触发路由提示
4. 延迟测试给出实测毫秒数（实测 309ms = 媒体通路往返；原生回环不经该通路）

## 7. 已知限制与后续优化

| 限制 | 说明 / 优化方向 |
|---|---|
| 采集周期 1024 帧 | 回环延迟下限 ~21ms；fork 插件将 `BUFFER_SIZE` 降至 240-480 帧可逼近 10-15ms |
| AAudio 双工不可用 | 「原始/语音识别」预置回环静音（双工拆分）；待 miniaudio/flutter_recorder 修复，或自研 AAudio 低延迟双工 |
| `cmd media_session volume --set` 失效 | ColorOS 限制；提示用户用音量键 |
| 原生崩溃（历史） | `uint8ListStream` 流订阅在 release 触发 native_crash，已弃用改 `getVolumeDb` 轮询 |
