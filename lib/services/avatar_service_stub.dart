// Stub implementation for non-web platforms
// This file is never actually used - on non-web platforms,
// the main avatar_service.dart uses image_picker directly.
// On web platforms, avatar_service_web.dart is used instead.

Future<String?> pickImageAsBase64Web() async {
  throw UnsupportedError('pickImageAsBase64Web is only available on web');
}
