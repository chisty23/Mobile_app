import 'photo_picker_stub.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart'
    if (dart.library.io) 'photo_picker_mobile.dart' as impl;

/// Cross-platform compressed image picker returning compact `data:image/jpeg;base64,...` strings.
Future<List<String>> pickCompressedImages({int maxCount = 3}) {
  return impl.pickCompressedImages(maxCount: maxCount);
}
