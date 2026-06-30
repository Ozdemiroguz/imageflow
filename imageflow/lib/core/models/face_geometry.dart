// Shared, plugin-free named types for face geometry.
//
// These replace the anonymous records (`({int left, int top, int width,
// int height})` / `({int x, int y})`) that were re-spelled across the
// processing, history, and analysis-widget layers, so the shape is declared
// once and read consistently (AUDIT M1).

/// Pixel-space rectangle of a detected face, sized by width/height.
typedef FaceRect = ({int left, int top, int width, int height});

/// A single pixel-space point on a face contour.
typedef ContourPoint = ({int x, int y});
