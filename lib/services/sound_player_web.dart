import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web audio player using package:web（相容 WASM + JS build）
class SoundPlayer {
  static web.HTMLAudioElement? _audio;

  static Future<void> play(String assetPath, double volume) async {
    try {
      _audio?.pause();
      _audio = web.HTMLAudioElement();
      // Flutter Web asset URL = /assets/<key>，key 本身已含 assets/ 前綴
      // 最終 URL: /assets/assets/audios/result/effect-01.mp3
      _audio!.src = '/assets/$assetPath';
      _audio!.volume = volume.clamp(0.0, 1.0);
      await _audio!.play().toDart;
    } catch (e) {
      // Browser autoplay policy 或路徑錯誤，靜默忽略
    }
  }

  static void stop() {
    _audio?.pause();
  }
}
