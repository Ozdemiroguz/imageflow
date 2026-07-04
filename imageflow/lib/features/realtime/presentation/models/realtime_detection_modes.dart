import 'package:flutter/foundation.dart';

/// Which realtime detectors are active. Each is an independent toggle, so any
/// combination can run — all three, some, one, or none.
///
/// "Document" bundles the OCR text gate and the edge detector (they are one
/// user-facing capability: find text, then find the paper's corners).
@immutable
class RealtimeDetectionModes {
  const RealtimeDetectionModes({
    this.face = true,
    this.document = true,
    this.object = true,
  });

  final bool face;
  final bool document;
  final bool object;

  /// True if nothing is enabled — the pipeline can skip all work for the frame.
  bool get isNoneEnabled => !face && !document && !object;

  RealtimeDetectionModes copyWith({bool? face, bool? document, bool? object}) {
    return RealtimeDetectionModes(
      face: face ?? this.face,
      document: document ?? this.document,
      object: object ?? this.object,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RealtimeDetectionModes &&
      other.face == face &&
      other.document == document &&
      other.object == object;

  @override
  int get hashCode => Object.hash(face, document, object);
}
