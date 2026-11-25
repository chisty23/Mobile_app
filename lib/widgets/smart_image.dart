import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Renders either an `http(s)` network image or a compressed `data:image/...;base64,...` URI.
class SmartListingImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget fallback;

  const SmartListingImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  static Uint8List? tryDecodeDataUri(String uri) {
    if (!uri.startsWith('data:image')) return null;
    final commaIdx = uri.indexOf(',');
    if (commaIdx == -1 || commaIdx >= uri.length - 1) return null;
    try {
      return base64Decode(uri.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return fallback;

    final memBytes = tryDecodeDataUri(trimmed);
    if (memBytes != null) {
      return Image.memory(
        memBytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return Image.network(
        trimmed,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black.withValues(alpha: 0.04),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return fallback;
  }
}

/// Interactive swipeable photo gallery with fullscreen zoom dialog.
class ListingPhotoGallery extends StatefulWidget {
  final List<String> images;
  final Widget fallback;
  final double height;
  final BorderRadius borderRadius;

  const ListingPhotoGallery({
    super.key,
    required this.images,
    required this.fallback,
    this.height = 240,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<ListingPhotoGallery> createState() => _ListingPhotoGalleryState();
}

class _ListingPhotoGalleryState extends State<ListingPhotoGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openZoomViewer(int initialIndex) {
    if (widget.images.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => _FullscreenPhotoDialog(
        images: widget.images,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validImages = widget.images.where((e) => e.trim().isNotEmpty).toList();
    if (validImages.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: const Color(0xFF667B72).withValues(alpha: 0.14),
        ),
        child: widget.fallback,
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: validImages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _openZoomViewer(i),
                child: SmartListingImage(
                  imageUrl: validImages[i],
                  fit: BoxFit.cover,
                  fallback: widget.fallback,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      validImages.length > 1
                          ? '${_page + 1}/${validImages.length}'
                          : 'Tap to zoom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (validImages.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < validImages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _page == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenPhotoDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenPhotoDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenPhotoDialog> createState() => _FullscreenPhotoDialogState();
}

class _FullscreenPhotoDialogState extends State<_FullscreenPhotoDialog> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: SmartListingImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  fallback: const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
