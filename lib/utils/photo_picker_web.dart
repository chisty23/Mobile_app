import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Picks up to [maxCount] image files via browser file dialog and compresses each
/// to a compact JPEG Data URI (max dimension 640px) suitable for fast Firestore storage.
Future<List<String>> pickCompressedImages({int maxCount = 3}) async {
  final completer = Completer<List<String>>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/*';
  input.multiple = true;

  void handleChange(web.Event _) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete([]);
      return;
    }

    final results = <String>[];
    final count = files.length < maxCount ? files.length : maxCount;
    for (var i = 0; i < count; i++) {
      final file = files.item(i);
      if (file == null) continue;
      final compressed = await _compressImageFile(file);
      if (compressed != null) {
        results.add(compressed);
      }
    }
    if (!completer.isCompleted) completer.complete(results);
  }

  input.onChange.listen(handleChange);
  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () => <String>[],
  );
}

Future<String?> _compressImageFile(web.File file) async {
  final readerCompleter = Completer<String?>();
  final reader = web.FileReader();

  reader.onload = ((web.Event _) {
    final dataUrl = (reader.result as JSString?)?.toDart;
    if (!readerCompleter.isCompleted) {
      readerCompleter.complete(dataUrl);
    }
  }).toJS;

  reader.onerror = ((web.Event _) {
    if (!readerCompleter.isCompleted) {
      readerCompleter.complete(null);
    }
  }).toJS;

  reader.readAsDataURL(file);
  final rawUrl = await readerCompleter.future;
  if (rawUrl == null || rawUrl.isEmpty) return null;

  final imgCompleter = Completer<String?>();
  final img = web.HTMLImageElement();

  img.onload = ((web.Event _) {
    const maxDim = 640;
    var w = img.naturalWidth;
    var h = img.naturalHeight;
    if (w == 0 || h == 0) {
      if (!imgCompleter.isCompleted) imgCompleter.complete(null);
      return;
    }
    if (w > maxDim || h > maxDim) {
      if (w >= h) {
        h = (h * maxDim / w).round();
        w = maxDim;
      } else {
        w = (w * maxDim / h).round();
        h = maxDim;
      }
    }

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = w;
    canvas.height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) {
      if (!imgCompleter.isCompleted) imgCompleter.complete(null);
      return;
    }
    ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
    final compressedUrl = canvas.toDataURL('image/jpeg', 0.65.toJS);
    if (!imgCompleter.isCompleted) {
      imgCompleter.complete(compressedUrl);
    }
  }).toJS;

  img.onerror = ((web.Event _) {
    if (!imgCompleter.isCompleted) imgCompleter.complete(null);
  }).toJS;

  img.src = rawUrl;
  return imgCompleter.future;
}
