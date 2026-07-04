# Object Detection — Native Feasibility & Integration Plan

> Goal: add on-device **object detection** as a third detection capability
> (faces, documents, **objects**) — implemented **natively** via platform
> channels, mirroring the proven corner-detection pattern (iOS Vision handler +
> Android Kotlin handler + a plugin-free Dart gateway).

**Status:** analysis/plan — no code yet. **Date:** 2026-07-03.

---

## 1. The honest technical finding first: object detection ≠ document gate

The realtime pipeline currently gates document-edge detection on the **OCR
text gate** ("frame has text → likely a document → run edge detection"). The
question was whether object detection could replace that control.

**It can't, semantically.** General-purpose object detectors (COCO-class
models, ML Kit base model) have **no "document/paper" class**. An object
detector would report "a salient rectangular thing" — but so is a laptop, a
book, or a cutting board. The OCR gate's signal ("it has text") is *the*
correct semantic test for "document", and it is already throttled (850ms
interval) and measured. **Keeping the text-based document control unchanged is
the right call** — replacing it would trade correctness for a per-cycle speed
gain we don't need.

- **Phase-3 option (deferred, measure-first):** use object/saliency detection
  as a *cheap pre-gate* that skips OCR entirely when the scene is empty. A
  modest possible win; only worth it if profile-mode traces show OCR dominating
  in the empty-scene case.

**So object detection enters the app as a NEW capability, not a replacement:**
realtime overlay draws tracked, labeled boxes; later, still-image scans
(camera/gallery) get an "objects" mode.

## 2. Native tech options per platform

| | Option A — models with labels | Option B — built-in, zero model files |
|---|---|---|
| **iOS** | Core ML detection model (e.g. YOLOv8n / MobileNet-SSD, ~5-10MB) via `VNCoreMLRequest`; runs on the Neural Engine | Vision saliency (`VNGenerateObjectnessBasedSaliencyImageRequest`): up to N salient-object boxes, **no labels** |
| **Android** | TFLite (`tensorflow-lite-task-vision`) with EfficientDet-Lite0 (~5MB, COCO 80 classes), optional GPU delegate | ML Kit **Android SDK natively in Kotlin** (`com.google.mlkit:object-detection`): STREAM_MODE, tracking IDs, coarse 5-category labels |
| **Demo value** | High — "cup 0.87" labeled boxes | Lower — boxes without (or with weak) labels |
| **Cost** | +~10-15MB app size, more native code, model licensing check | Minimal code, no assets |

Both options keep everything **on-device** and **native** (Swift/Kotlin behind
a MethodChannel), consistent with the existing corner/PDF handlers.

## 3. Architecture fit — the hardened structure makes this cheap

The channel + Dart contract mirrors corner detection exactly:

```
channel: com.oguzhan.imageflow/object_detection
  detectObjects(imagePath)                    → still images (Phase 2)
  detectObjectsFromFrame(width,height,rotation,
      bytes/bytesPerRow | yBytes/uBytes/vBytes/strides, format)
      → [{label, confidence, left, top, right, bottom (0-1), trackingId?}]
```

Dart side (all existing patterns, no new layer inventions):
- `core/platform/object_detector.dart` — interface (like `CornerDetector`);
  frame path returns `null` on error (drop-frame hot-path contract), file path
  returns `Result` — same dual contract corner detection already documents.
- `core/services/native_object_detection_service.dart` — channel impl
  (mirrors `NativeCornerDetectionService`).
- `core/models/detected_object_info.dart` — plugin-free value object
  (label, confidence, normalized rect, trackingId) — anti-corruption boundary.
- **Realtime:** scheduler gains an object slot (`tryBeginObjectDetection` /
  `endObjectDetection` + `objectInterval` in config — the exact try-acquire
  pattern face/ocr/edge already use); pipeline calls it with the **already
  shared** per-frame conversion; results flow through `DetectionOutputPort`
  (new object methods) into the overlay store; a new box+label painter under
  `RepaintBoundary` with a `shouldRepaint` diff, like the face/document
  painters.
- Native handler replicates the corner handler's concurrency shape:
  background queue/executor, main-thread result post, `frameBusy` backpressure,
  `autoreleasepool` (iOS) — all patterns we just audited and fixed.

## 4. Realtime performance plan

- **Budget:** detection runs natively off the UI thread; the Dart cost is one
  channel call + result decode per slot. Start `objectInterval` at ~300ms
  (between face's 180 and edge's 260) and tune in profile mode.
- **Backpressure:** the pipeline's frame-drop semantics (busy flags, null =
  drop) already prevent pile-up; the native handler adds its own frameBusy
  gate like corner V2.
- **Expected native cost:** iOS Core ML small detectors on ANE ≈ 10-30ms/frame
  at low res; Android EfficientDet-Lite0 CPU ≈ 50-100ms midrange (GPU delegate
  faster) / ML Kit STREAM_MODE comparable with tracking amortization.
- **Instrumentation:** extend `PerfTrace` sampling with `objectMs` next to
  ocr/face/edge — tuning is measured, not guessed.
- **No change to existing costs:** OCR gate (850ms), face (180ms), edge (260ms)
  intervals stay as-is; the object slot is additive and independently
  throttled. Realtime document scanning perf is unchanged by design.

## 5. Showcase value

High. The narrative becomes: *three on-device CV/ML capabilities — face + text
via ML Kit, document geometry + objects via native platform channels (Vision /
Core ML on iOS, OpenCV / TFLite on Android)* — and the clean-architecture
proof: adding an entire detection mode touches a bounded, predictable set of
files (interface + service + slot + port methods + painter) with zero layer
violations.

## 6. Phased plan

1. **Phase 1 — realtime objects:** native handlers (iOS + Android) + channel +
   Dart gateway + scheduler slot + port/overlay/painter + config + PerfTrace +
   Dart-side tests (scheduler slot, pipeline characterization extension,
   service contract with mocked channel). *Native code can't be compiled here —
   on-device validation by the developer (profile mode).*
2. **Phase 2 — still-image objects:** `detectObjects(imagePath)` + processing
   integration (third mode or standalone flow), result UI with boxes/labels,
   history persistence + mapper + tests.
3. **Phase 3 (optional, measured):** object/saliency pre-gate for OCR — only
   if profile traces justify it.
