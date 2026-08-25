import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:motodub/features/shared/photo_viewer.dart";

/// Pumps a one-button home that opens the viewer through the same public
/// entry point production uses (showModalBottomSheet wrapper).
Future<void> _pumpOpener(WidgetTester tester, String url) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key("open-viewer"),
              onPressed: () => showPhotoViewer(context, url),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const url = "http://10.0.2.2:3000/uploads/bike.png";

  testWidgets("viewer shows the requested photo full-screen", (tester) async {
    await _pumpOpener(tester, url);
    await tester.tap(find.byKey(const Key("open-viewer")));
    // Sheet entrance animation; fixed pumps keep unreachable photo requests
    // from looping (same convention as driver_card_test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PhotoViewer), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, url);
    // Spec: pinch-zoom between 1x and 4x, pan clamped by InteractiveViewer.
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 4);
    expect(viewer.transformationController, isNotNull);
  });

  testWidgets("the close button dismisses the viewer", (tester) async {
    await _pumpOpener(tester, url);
    await tester.tap(find.byKey(const Key("open-viewer")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key("photo-viewer-close")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets("double-tap toggles between fit and zoomed-in", (tester) async {
    await _pumpOpener(tester, url);
    await tester.tap(find.byKey(const Key("open-viewer")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    double scale() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    expect(scale(), moreOrLessEquals(1));

    // No tester.doubleTap in this flutter_test — two taps inside the
    // double-tap window (with a small clock advance between).
    await tester.tap(find.byType(PhotoViewer));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(PhotoViewer));
    await tester.pump();
    expect(scale(), greaterThan(2)); // zoomed in

    await tester.tap(find.byType(PhotoViewer));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(PhotoViewer));
    await tester.pump();
    expect(scale(), moreOrLessEquals(1)); // back to fit

    // Let the recognizer's double-tap window timer expire before teardown.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
