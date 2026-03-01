import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: use dart:html FileUploadInputElement
/// Must be called synchronously from user gesture (no await before click())
Future<String?> pickImageAsBase64Web() {
  final completer = Completer<String?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click(); // 必須同步執行，不能有任何 await 在前面

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsDataUrl(files[0]);
    reader.onLoad.listen((_) {
      completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) => completer.complete(null));
  });

  // 若使用者取消（關閉 dialog 沒選檔），5 分鐘後 timeout
  Future.delayed(const Duration(seconds: 300), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
