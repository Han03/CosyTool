import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:http/http.dart' as http;

/// Edge-TTS 音色（中文，参照 AnkiNotes 的 EdgeTTSVoice 枚举）。
class TtsVoice {
  const TtsVoice(this.id, this.label);

  final String id;
  final String label;

  static const List<TtsVoice> chinese = <TtsVoice>[
    TtsVoice('zh-CN-YunxiNeural', '云希（男声·年轻）'),
    TtsVoice('zh-CN-YunyangNeural', '云扬（男声·新闻）'),
    TtsVoice('zh-CN-YunjianNeural', '云健（男声·成熟）'),
    TtsVoice('zh-CN-XiaoxiaoNeural', '晓晓（女声·活泼）'),
    TtsVoice('zh-CN-XiaoyiNeural', '晓伊（女声·温柔）'),
    TtsVoice('zh-CN-YunxiaNeural', '云夏（男声·少年）'),
    TtsVoice('zh-CN-XiaomoNeural', '晓墨（女声·知性）'),
    TtsVoice('zh-CN-YunhaoNeural', '云皓（男声·浑厚）'),
  ];
}

/// Edge-TTS 语音合成服务。
///
/// 接口协议（POST {serviceUrl}/v1/audio/speech）：
/// 请求体 { input, voice, speed, pitch, style, volume }，响应为 MP3 二进制。
/// 实现策略（参照 AnkiNotes TTSService）：
/// - 文本按句子切分，逐句合成 + 播放，句子进度可高亮
/// - 合成固定 speed 1.0，播放时用 setPlaybackRate 做语速后处理
/// - 内存缓存 + 下一句预合成，保证句间连续
class TtsService {
  TtsService();

  final AudioPlayer _player = AudioPlayer();

  String serviceUrl = 'https://tts.maxh.ccwu.cc';
  String voice = 'zh-CN-YunxiNeural';
  double speed = 1.0;
  double pitch = 0;

  List<String> _sentences = const [];
  final Map<int, Uint8List> _audioCache = {};
  final Map<int, Future<void>> _preloadFutures = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  /// 状态（页面订阅刷新）。
  bool isSpeaking = false;
  bool isPaused = false;
  bool isLoading = false;
  int currentIndex = 0;
  int get total => _sentences.length;
  List<String> get sentences => _sentences;
  String get currentText =>
      currentIndex < _sentences.length ? _sentences[currentIndex] : '';

  VoidCallback? onStateChanged;

  TtsService._init();

  /// 创建并初始化播放器（页面 initState 调用）。
  static Future<TtsService> create() async {
    final s = TtsService._init();
    s._subs.add(s._player.onPlayerComplete.listen((_) => s._onSentenceFinished()));
    return s;
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
  }

  /// 按句子切分文本（。！？!?\n 为界，与 AnkiNotes 保持一致）。
  static List<String> splitIntoSentences(String text) {
    final result = <String>[];
    final separators = RegExp('[。！？!?\n]');
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final c = String.fromCharCode(char);
      buffer.write(c);
      if (separators.hasMatch(c)) {
        final trimmed = buffer.toString().trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
        buffer.clear();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) result.add(rest);
    return result;
  }

  /// 开始朗读。
  void speak(String text, {int startIndex = 0}) {
    _player.stop();
    _audioCache.clear();
    _preloadFutures.clear();
    _sentences = splitIntoSentences(text);
    if (_sentences.isEmpty) return;
    currentIndex = startIndex.clamp(0, _sentences.length - 1);
    isSpeaking = true;
    isPaused = false;
    _notify();
    _speakCurrent();
  }

  void _speakCurrent() {
    if (!isSpeaking || currentIndex >= _sentences.length) {
      _finish();
      return;
    }
    final sentence = _sentences[currentIndex];

    // 内存缓存命中
    final cached = _audioCache[currentIndex];
    if (cached != null) {
      _playBytes(cached);
      _preloadNext();
      return;
    }

    isLoading = true;
    _notify();
    _synthesize(sentence).then((bytes) {
      if (!isSpeaking || currentIndex >= _sentences.length) return;
      if (_sentences[currentIndex] != sentence) return; // 句子已切换
      _audioCache[currentIndex] = bytes;
      if (isPaused) return; // 暂停时只缓存
      isLoading = false;
      _playBytes(bytes);
      _preloadNext();
    }).catchError((Object e) {
      if (!isSpeaking) return;
      isLoading = false;
      onError?.call('合成失败：$e');
      _notify();
      _skipToNextInternal(); // 失败跳过当前句，继续朗读
    });
  }

  /// 合成并播放时预取下一句（防止句间卡顿）。
  void _preloadNext() {
    final next = currentIndex + 1;
    if (next >= _sentences.length) return;
    if (_audioCache.containsKey(next)) return;
    if (_preloadFutures.containsKey(next)) return;
    _preloadFutures[next] = _synthesize(_sentences[next]).then((bytes) {
      _audioCache[next] = bytes;
    }).catchError((Object _) {});
  }

  Future<Uint8List> _synthesize(String text) async {
    final url = '$serviceUrl/v1/audio/speech';
    final resp = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': text,
            'voice': voice,
            'speed': 1.0,
            'pitch': '${pitch.round()}',
            'style': 'general',
            'volume': '0',
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    if (resp.bodyBytes.isEmpty) throw Exception('空音频');
    return resp.bodyBytes;
  }

  Future<void> _playBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.play(BytesSource(bytes));
    await _player.setPlaybackRate(speed);
  }

  void _onSentenceFinished() {
    if (!isSpeaking || isPaused) return;
    _skipToNextInternal();
  }

  void _skipToNextInternal() {
    currentIndex += 1;
    if (currentIndex >= _sentences.length) {
      _finish();
      return;
    }
    _notify();
    _speakCurrent();
  }

  void pause() {
    if (!isSpeaking || isPaused) return;
    isPaused = true;
    _player.pause();
    _notify();
  }

  void resume() {
    if (!isSpeaking || !isPaused) return;
    isPaused = false;
    _player.resume();
    _notify();
  }

  void stop() {
    isSpeaking = false;
    isPaused = false;
    isLoading = false;
    currentIndex = 0;
    _player.stop();
    _notify();
  }

  /// 跳转到指定句子开始朗读。
  void skipTo(int index) {
    if (!isSpeaking || index < 0 || index >= _sentences.length) return;
    currentIndex = index;
    isPaused = false;
    _player.stop();
    _notify();
    _speakCurrent();
  }

  void skipNext() {
    if (!isSpeaking) return;
    currentIndex += 1;
    if (currentIndex >= _sentences.length) {
      _finish();
      return;
    }
    isPaused = false;
    _player.stop();
    _notify();
    _speakCurrent();
  }

  void skipPrevious() {
    if (!isSpeaking || currentIndex <= 0) return;
    currentIndex -= 1;
    isPaused = false;
    _player.stop();
    _notify();
    _speakCurrent();
  }

  void _finish() {
    isSpeaking = false;
    isPaused = false;
    isLoading = false;
    currentIndex = 0;
    _notify();
    onComplete?.call();
  }

  void _notify() {
    onStateChanged?.call();
  }

  /// 合成失败回调（参数为错误信息）。
  void Function(String message)? onError;
  VoidCallback? onComplete;
}
