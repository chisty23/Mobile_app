import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get supportsDevicePhotoPicker => true;

const int _maxEncodedChars = 220000;

/// Picks up to [maxCount] image files via browser file dialog and compresses each
/// to a compact JPEG Data URI suitable for Firestore storage within Spark limits.
Future<List<String>> pickCompressedImages({
  int maxCount = 3,
  int maxDimension = 640,
}) async {
  final completer = Completer<List<String>>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/*';
  input.multiple = maxCount > 1;

  StreamSubscription<web.Event>? changeSub;
  web.EventListener? focusHandler;
  web.EventListener? cancelHandler;

  void finish(List<String> results) {
    changeSub?.cancel();
    if (focusHandler != null) {
      web.window.removeEventListener('focus', focusHandler);
      focusHandler = null;
    }
    if (cancelHandler != null) {
      input.removeEventListener('cancel', cancelHandler);
      cancelHandler = null;
    }
    if (!completer.isCompleted) {
      completer.complete(results);
    }
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(const []);
      return;
    }

    final results = <String>[];
    final count = files.length < maxCount ? files.length : maxCount;
    for (var i = 0; i < count; i++) {
      final file = files.item(i);
      if (file == null) continue;
      final compressed = await _compressImageFile(file, maxDimension);
      if (compressed != null) {
        results.add(compressed);
      }
    }
    finish(results);
  });

  cancelHandler = ((web.Event _) {
    finish(const []);
  }).toJS;
  input.addEventListener('cancel', cancelHandler);

  // Fallback for browsers that omit the input 'cancel' event.
  focusHandler = ((web.Event _) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted && (input.files?.length ?? 0) == 0) {
        finish(const []);
      }
    });
  }).toJS;
  web.window.addEventListener('focus', focusHandler);

  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      finish(const []);
      return const <String>[];
    },
  );
}

Future<String?> _compressImageFile(web.File file, int requestedMaxDim) async {
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
    final naturalW = img.naturalWidth;
    final naturalH = img.naturalHeight;
    if (naturalW == 0 || naturalH == 0) {
      if (!imgCompleter.isCompleted) imgCompleter.complete(null);
      return;
    }

    final candidates = <(int, double)>[
      (requestedMaxDim, 0.68),
      if (requestedMaxDim > 480) (480, 0.56),
      (360, 0.45),
    ];

    String? bestUrl;
    for (final (maxDim, quality) in candidates) {
      var w = naturalW;
      var h = naturalH;
      if (w > maxDim || h > maxDim) {
        if (w >= h) {
          h = (h * maxDim / w).round().clamp(1, maxDim);
          w = maxDim;
        } else {
          w = (w * maxDim / h).round().clamp(1, maxDim);
          h = maxDim;
        }
      }

      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas.width = w;
      canvas.height = h;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (ctx == null) {
        if (!imgCompleter.isCompleted) imgCompleter.complete(null);
        return;
      }
      ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
      final encoded = canvas.toDataURL('image/jpeg', quality.toJS);
      bestUrl = encoded;
      if (encoded.length <= _maxEncodedChars) {
        break;
      }
    }

    if (!imgCompleter.isCompleted) {
      imgCompleter.complete(bestUrl);
    }
  }).toJS;

  img.onerror = ((web.Event _) {
    if (!imgCompleter.isCompleted) imgCompleter.complete(null);
  }).toJS;

  img.src = rawUrl;
  return imgCompleter.future;
}
