import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: use dart:html FileUploadInputElement + Canvas 壓縮
/// 選圖後透過 Canvas 縮圖至 100x100, JPEG 70%，base64 約 3-8KB
Future<String?> pickImageAsBase64Web() {
  final completer = Completer<String?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);

    reader.onLoad.listen((_) {
      final dataUrl = reader.result?.toString();
      if (dataUrl == null) {
        completer.complete(null);
        return;
      }

      // 用 Canvas 壓縮到 100x100, JPEG 70%
      final img = html.ImageElement()..src = dataUrl;
      img.onLoad.listen((_) {
        final canvas = html.CanvasElement(width: 100, height: 100);
        final ctx = canvas.context2D;
        ctx.drawImageScaled(img, 0, 0, 100, 100);
        final compressed = canvas.toDataUrl('image/jpeg', 0.7);
        completer.complete(compressed);
      });
      img.onError.listen((_) => completer.complete(dataUrl)); // fallback
    });

    reader.onError.listen((_) => completer.complete(null));
  });

  Future.delayed(const Duration(seconds: 300), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
