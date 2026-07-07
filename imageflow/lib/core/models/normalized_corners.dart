import 'package:document_scan/document_scan.dart' as ds;

/// 4 corner points in normalized 0-1 coordinates (for realtime overlay).
class NormalizedCorners {
  const NormalizedCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final ({double x, double y}) topLeft;
  final ({double x, double y}) topRight;
  final ({double x, double y}) bottomRight;
  final ({double x, double y}) bottomLeft;
}

/// Conversions between the app's [NormalizedCorners] and the document_scan
/// package's [ds.DocumentCorners]. Both use the same normalized 0..1 record
/// shape, so these are field-for-field maps — kept here, in one place, so the
/// app↔package coupling has a single home instead of being re-inlined at every
/// call site (the corner-adjust screen, the crop service, the realtime
/// auto-capture feed, and the realtime detector adapter).
extension NormalizedCornersPackageX on NormalizedCorners {
  ds.DocumentCorners toPackage() => ds.DocumentCorners(
    topLeft: topLeft,
    topRight: topRight,
    bottomRight: bottomRight,
    bottomLeft: bottomLeft,
  );
}

extension DocumentCornersAppX on ds.DocumentCorners {
  NormalizedCorners toNormalized() => NormalizedCorners(
    topLeft: topLeft,
    topRight: topRight,
    bottomRight: bottomRight,
    bottomLeft: bottomLeft,
  );
}
