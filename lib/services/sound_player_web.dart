import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web 音效播放
///
/// 優先使用 Web Audio API：播放短音效通常不會搶走「媒體播放」音訊焦點，
/// 因此能與背景音樂同時播放（Android 效果最佳；iOS 視 Safari 版本為盡力而為）。
/// 若 Web Audio 因任何原因失敗，會自動退回原本的 <audio> 播放方式
/// （至少能出聲，行為等同先前版本），確保不會比原本更糟。
class SoundPlayer {
  static web.AudioContext? _ctx;
  static final Map<String, web.AudioBuffer> _cache = {};
  static web.AudioBufferSourceNode? _current;
  static web.HTMLAudioElement? _fallbackAudio;

  static web.AudioContext _context() => _ctx ??= web.AudioContext();

  static Future<void> play(String assetPath, double volume) async {
    final played = await _playViaWebAudio(assetPath, volume);
    if (!played) _playViaElement(assetPath, volume);
  }

  /// 嘗試以 Web Audio 播放，成功回 true
  static Future<bool> _playViaWebAudio(String assetPath, double volume) async {
    try {
      final ctx = _context();
      // 受瀏覽器 autoplay policy 影響時，於使用者操作後恢復
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      final buffer = await _load(ctx, assetPath);
      if (buffer == null) return false;

      final source = ctx.createBufferSource();
      source.buffer = buffer;

      final gain = ctx.createGain();
      gain.gain.value = volume.clamp(0.0, 1.0);

      source.connect(gain);
      gain.connect(ctx.destination);

      _current = source;
      source.start();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 載入並解碼音檔（解碼後快取，之後重播免重新下載/解碼）
  static Future<web.AudioBuffer?> _load(web.AudioContext ctx, String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null) return cached;
    // Flutter Web asset URL = /assets/<key>，key 本身已含 assets/ 前綴
    final resp = await web.window.fetch('/assets/$assetPath'.toJS).toDart;
    final arrayBuffer = await resp.arrayBuffer().toDart;
    final audioBuffer = await ctx.decodeAudioData(arrayBuffer).toDart;
    _cache[assetPath] = audioBuffer;
    return audioBuffer;
  }

  /// 退回方案：用 <audio> 元素播放（行為同先前版本）
  static void _playViaElement(String assetPath, double volume) {
    try {
      _fallbackAudio?.pause();
      final audio = web.HTMLAudioElement();
      audio.src = '/assets/$assetPath';
      audio.volume = volume.clamp(0.0, 1.0);
      _fallbackAudio = audio;
      audio.play();
    } catch (e) {
      // 靜默忽略
    }
  }

  static void stop() {
    try {
      _current?.stop();
    } catch (_) {}
    _current = null;
    _fallbackAudio?.pause();
  }
}
