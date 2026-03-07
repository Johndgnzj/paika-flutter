// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web audio player using HTML5 AudioElement（直接繞過 Flutter plugin 系統）
class SoundPlayer {
  static html.AudioElement? _audio;

  static Future<void> play(String assetPath, double volume) async {
    try {
      _audio?.pause();
      _audio = html.AudioElement()
        ..src = '/assets/$assetPath'
        ..volume = volume.clamp(0.0, 1.0)
        ..load();
      await _audio!.play();
    } catch (_) {
      // Browser autoplay policy 或其他錯誤，靜默忽略
    }
  }

  static void stop() {
    _audio?.pause();
  }
}
