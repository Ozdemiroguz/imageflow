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

## 2. Native tech — DECISION: labeled COCO-80 on both platforms

Chosen after per-platform research (see below). The whole showcase value is in
**labeled, tracked boxes that read the same on both platforms** ("person 0.91",
"cup 0.87"). The built-in zero-model paths were rejected because they produce
inconsistent, weak labels (iOS Vision saliency = boxes with **no** labels;
Android ML Kit base classifier = only 5 coarse buckets Fashion/Food/Home/Place/
Plant). An asymmetric, unlabeled demo reads worse in review than one consistent
labeled model per platform.

| | Chosen (labeled, COCO-80) | Rejected (built-in, zero model) |
|---|---|---|
| **iOS** | **Core ML via `VNCoreMLRequest`** — a license-clean COCO detector from **Apple's model gallery** (YOLOv3-Tiny or MobileNetV2-SSDLite). Emits `VNRecognizedObjectObservation` (box + label + confidence). ~10-25ms/frame on ANE. **NOT** Ultralytics YOLOv8/11 — those are AGPL-3.0 (viral license, wrong for a portfolio). | Vision saliency (`VNGenerateObjectnessBasedSaliencyImageRequest`) → boxes, **no labels** |
| **Android** | **EfficientDet-Lite0** (~4.5MB, COCO-80, Apache-2.0) via **MediaPipe Tasks `ObjectDetector`** (`com.google.mediapipe:tasks-vision` — the LiteRT-era successor to the now-frozen `tensorflow-lite-task-vision`). Real COCO names. | ML Kit object-detection SDK — zero model but only 5 coarse categories |

**Performance notes that shaped the design:**
- **iOS:** reuse ONE `VNCoreMLRequest` + a `VNSequenceRequestHandler` across
  frames (not per-frame allocation like the corner path); `MLModelConfiguration
  .computeUnits = .all` (ANE); Vision downscales to the model input internally
  (no pre-shrink); keep the existing `autoreleasepool` + `frameBusy` + BGRA
  `CVPixelBuffer` path unchanged.
- **Android:** EfficientDet-Lite0 wants 320×320, so a per-frame resize is
  unavoidable; feed from the frame with minimal Bitmap churn (reuse one Bitmap,
  recycle only on teardown — respecting the leak fix we just landed). Detector
  created once, closed on teardown, CPU+XNNPACK (GPU delegate overhead isn't
  worth it at this model size).
- **Both:** the object slot runs on the realtime scheduler at its own interval
  (~300ms), so it is throttled far below per-frame — the model's per-call cost
  is amortized and never competes for the 33ms frame budget. This is why the
  "labeled but slightly heavier" choice costs nothing perceptible in realtime.

Everything stays **on-device** and **native** (Swift/Kotlin behind a
MethodChannel), consistent with the existing corner/PDF handlers.

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

## 6. Phased plan & build order

**Build order rationale:** native code can't be compiled/run in this
environment, so build the **testable Dart skeleton first** (green tests prove
the architecture), then add the native handlers, which the developer compiles
and validates on-device (profile mode).

### Phase 1 — realtime objects
- **1a — Dart skeleton (testable):** `ObjectDetector` interface
  (`core/platform/`), `DetectedObjectInfo` model (`core/models/`, plugin-free:
  label, confidence, normalized rect, trackingId?), `NativeObjectDetectionService`
  (channel impl), scheduler object slot (`tryBeginObjectDetection`/`endObjectDetection`
  + `objectInterval` in config).
- **1b — wire-in:** `DetectionOutputPort` object methods + overlay store fields
  + a box+label painter under `RepaintBoundary` with a `shouldRepaint` diff;
  pipeline calls the object slot with the already-shared per-frame conversion;
  `PerfTrace` gains `objectMs`.
- **1c — Dart tests:** scheduler object slot, service contract (mocked channel),
  pipeline characterization extension.
- **1d — native handlers:** iOS Core ML handler (reuse VNCoreMLRequest +
  VNSequenceRequestHandler; Apple gallery model bundled) + Android MediaPipe
  ObjectDetector handler (EfficientDet-Lite0 asset) + channel case
  `detectObjectsFromFrame`. *Compiled & validated on-device by the developer.*

### Phase 2 — still-image objects
`detectObjects(imagePath)` + processing integration (third mode or standalone
flow), result UI with boxes/labels, history persistence + mapper + tests.

### Phase 3 (optional, measured)
The object slot as a selectable **document-scan gate strategy**: abstract the
edge gate (`DetectionGate`) into `TextPresenceGate` (current OCR) +
`ObjectPresenceGate` (new), chosen by realtime mode — keeps BOTH gates, user
picks per scan. Only if profile traces + product value justify it.
