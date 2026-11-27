import 'dart:io' show Platform;
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('passiton/media_picker');

bool get supportsDevicePhotoPicker => Platform.isAndroid || Platform.isIOS;

/// Picks and compresses images natively on Android & iOS via MethodChannel.
Future<List<String>> pickCompressedImages({
  int maxCount = 3,
  int maxDimension = 640,
}) async {
  if (!supportsDevicePhotoPicker) {
    return const [];
  }
  try {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'pickCompressedImages',
      {'maxCount': maxCount, 'maxDimension': maxDimension},
    );
    if (result == null) return const [];
    return result
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toList();
  } on PlatformException {
    return const [];
  } on MissingPluginException {
    return const [];
  }
}
