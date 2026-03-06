// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:html' as html;

/// 偵測是否為 TV 瀏覽器（Samsung Tizen / LG webOS / 其他 SmartTV）
bool isTvBrowser() {
  final ua = html.window.navigator.userAgent;
  return ua.contains('Tizen') ||
      ua.contains('webOS') ||
      ua.contains('SMART-TV') ||
      ua.contains('SmartTV') ||
      ua.contains('HbbTV');
}

/// 使用 window.prompt 呼出 TV 內建鍵盤
String? promptInput(String message, String defaultValue) {
  final result = js.context.callMethod('prompt', [message, defaultValue]);
  return result as String?;
}
