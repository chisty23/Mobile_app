import 'package:flutter/material.dart';

import 'formatters.dart';
import 'photo_picker_stub.dart'
    if (dart.library.js_interop) 'photo_picker_web.dart'
    if (dart.library.io) 'photo_picker_mobile.dart' as impl;

/// Whether the current platform supports native/browser device image picking.
bool get supportsDevicePhotoPicker => impl.supportsDevicePhotoPicker;

/// Cross-platform compressed image picker returning compact `data:image/jpeg;base64,...` strings.
Future<List<String>> pickCompressedImages({
  int maxCount = 3,
  int maxDimension = 640,
}) {
  return impl.pickCompressedImages(
    maxCount: maxCount,
    maxDimension: maxDimension,
  );
}

/// Picks a single compressed avatar photo from the user's device with user feedback.
Future<String?> pickSingleAvatarFromDevice(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!supportsDevicePhotoPicker) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Device gallery picker works on Web, Android, and iOS. On desktop, paste an https:// URL.',
        ),
      ),
    );
    return null;
  }
  final picked = await pickCompressedImages(maxCount: 1, maxDimension: 360);
  if (picked.isEmpty) return null;
  final photo = picked.first.trim();
  if (!AppFormatters.isValidImageSource(photo)) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Selected photo exceeded compact size limit; try a smaller image or an https:// URL.',
        ),
      ),
    );
    return null;
  }
  return photo;
}
