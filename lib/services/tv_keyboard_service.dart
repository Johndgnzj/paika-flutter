import 'tv_keyboard_service_stub.dart'
    if (dart.library.html) 'tv_keyboard_service_web.dart' as impl;

/// 偵測是否為 TV 瀏覽器
bool isTvBrowser() => impl.isTvBrowser();

/// 使用 TV 內建鍵盤輸入（window.prompt）
String? promptInput(String message, String defaultValue) =>
    impl.promptInput(message, defaultValue);
