import "package:flutter/material.dart";

import "../../core/theme/app_theme.dart";

/// Opens [url] as a full-screen photo viewer on top of the current page.
///
/// A modal bottom sheet stretched edge-to-edge (the booking-sheet convention,
/// Task 3.5) rather than a named route: the deck owns horizontal drags, so the
/// hero photo must open on TAP only, and a modal sheet keeps that wiring local
/// to the caller. `enableDrag: false` hands every drag to the zoom-pan.
Future<void> showPhotoViewer(BuildContext context, String url) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.black,
    builder: (_) => PhotoViewer(url: url),
  );
}

/// Pinch-zoom / two-axis pan view of one photo (§5 hero, full-screen):
/// clamped pan, 1x–4x, dark backdrop, X to close, tap backdrop to dismiss,
/// double-tap toggles between fit and zoomed.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.url});

  final String url;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  Offset? _lastDoubleTapDown;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  /// Flutter docs recipe: keep the tapped point fixed while scaling about it.
  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    final position =
        _lastDoubleTapDown ?? MediaQuery.sizeOf(context).center(Offset.zero);
    _transform.value = Matrix4.identity()
      ..translateByDouble(-position.dx * (_doubleTapScale - 1),
          -position.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          onDoubleTapDown: (details) => _lastDoubleTapDown = details.localPosition,
          onDoubleTap: _toggleZoom,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                // DESIGN §8 — broken images degrade, never crash or show a
                // broken-image glyph.
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_taxi_rounded,
                        size: 44, color: AppColors.faint),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            key: const Key("photo-viewer-close"),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
