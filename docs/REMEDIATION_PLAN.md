# ImageFlow — Remediation Plan

> The concrete change-list that turns ImageFlow from "above-portfolio-grade" into a **reference-grade showcase**.
> Each item maps to a finding ID in [AUDIT.md](./AUDIT.md), names the **files to touch**, the **steps**, and an **acceptance criterion** you can check. Ordered so each step unblocks the next.

**How to use this:** work top-to-bottom. Phases 1–3 are the showcase blockers; Phase 4 is strong polish; Phase 5 is quick consistency wins you can interleave anytime. Nothing here changes app behavior — it changes *structure, testability, and boundaries*.

**Done = ** `flutter analyze` clean · `flutter test` green · the acceptance box of every item below ticked.

---

## Progress (branch `refactor/showcase-hardening`)

Every commit below kept `flutter analyze` clean and all 188 tests green.

| Item | Status | Commit |
|---|---|---|
| **D1** — extract `ContentDetector`/`DocumentCropper`/`CornerDetector` interfaces, bind interface→impl | ✅ Done | `6e586c6` |
| **G1** — inject `CaptureController` into `OpenCaptureDialogAction` | ✅ Done | `f3aa2c7` |
| **N2** — make `DetectionResult` plugin-free (`DetectedFace`/`RecognizedTextData`; translate ML Kit at the boundary) | ✅ Done | `c5e7fcf` |
| **N3** — wrap `image_picker` behind `ImagePickerGateway` | ✅ Done | `f4002a7` |
| **§8** — consolidate duplicate route-lifecycle coordinators → `CameraRouteLifecycleController` | ✅ Done | `9af2a59` |
| **§8** — merge batch transitions + mutator → `BatchItemStateManager` | ✅ Done | `d5e7d3e` |
| **N1** — contain `camera` type leakage (19 files) | ⏸️ Deferred | — |
| **4c** — relabel mis-filed view-models (`RealtimeOverlayStateStore`, `DocumentActionsPresenter`) | ⬜ Pending | — |
| **4d** — split `ProcessingRepositoryImpl` + DRY document pipeline (A1/A2/A3) | ⬜ Pending | — |
| **Phase 5** — consistency quick-wins (onLog, named types, `// ignore` justifications, naming) | ⬜ Pending | — |
| **Phase 3** — tests (realtime/batch/repo) + widget tests + CI | ⬜ Pending (LAST, by request) | — |

> **N1 deferred (decision):** `camera` usage is concentrated in the realtime live-frame pipeline (`CameraImage`, `ResolutionPreset`, frame rotation), which is inherently plugin-adjacent infrastructure rather than a single shared-model leak like N2. Fully wrapping it is a large realtime refactor with higher behavior risk and lower payoff than N2/N3, so it is parked as future work. The high-value boundary leaks (the shared `core` model — N2 — and the unwrapped `image_picker` — N3) are closed.

---

## Phase 0 — Baseline (do once, ~10 min)

Lock in a green starting point so every later change is measurable.

- [ ] `cd imageflow && flutter analyze` → confirm "No issues found".
- [ ] `flutter test --coverage` → record the current passing count and baseline coverage (`lcov`/`genhtml` or just the summary).
- [ ] Create a working branch: `git checkout -b refactor/showcase-hardening`.

**Acceptance:** baseline coverage number written down; branch created off a clean `main`.

---

## Phase 1 — Dependency Inversion at the service seam  *(root cause — unblocks everything)*

> **AUDIT: D1 (MAJOR), G1 (MAJOR)** · Std §4-D, §9, §16.
> Today every collaborator is injected as a **concrete** class, so the processing repository and detection services can't be mocked → can't be tested. Introduce interfaces for the three seams that actually matter, then bind interface→impl.

### 1.1 Extract detection/crop/corner interfaces

**Files to create**
- `lib/features/processing/domain/services/content_detector.dart` — `abstract interface class ContentDetector { Future<DetectionResult> detect({required String imagePath, ProcessingType? preferredType}); }`
- `lib/features/processing/domain/services/document_cropper.dart` — `abstract interface class DocumentCropper { Future<void> processDocument({required String sourcePath, required String targetPath, RecognizedText? recognizedText}); }`
- `lib/core/platform/corner_detector.dart` — `abstract interface class CornerDetector { Future<DocumentCorners?> detectCorners({required String imagePath}); Future<NormalizedCorners?> detectCornersFromFrame(...); }`

> ⚠️ **Boundary note:** `DetectionResult` and `RecognizedText` in these signatures still carry ML-Kit types today — that's **N2**, fixed in Phase 2. Do Phase 1 first (cheap, unblocks tests), then Phase 2 removes the leak from the now-abstract surface. Keeping the order this way means Phase 1 touches only DI wiring, not type-mapping.

**Files to edit**
- `processing/data/services/content_detection_service.dart` → `class ContentDetectionService implements ContentDetector` (signature already matches `detect(...)` at `:27`).
- `processing/data/services/document_crop_service.dart` → `implements DocumentCropper` (matches `processDocument(...)` at `:30`).
- `core/services/native_corner_detection_service.dart` → `implements CornerDetector` (matches `detectCorners(...)` at `:25`).
- `processing/data/repositories/processing_repository_impl.dart:24-35` → change the three constructor fields to the **interface** types (`ContentDetector _contentDetection`, `DocumentCropper _documentCrop`).
- `processing/di/processing_dependencies.dart:12-33` → bind the interfaces:
  ```dart
  Get.lazyPut<ContentDetector>(ContentDetectionService.new);
  Get.lazyPut<DocumentCropper>(() => DocumentCropService(cornerDetection: Get.find<CornerDetector>()));
  Get.lazyPut<CornerDetector>(NativeCornerDetectionService.new);
  ```
  and `ProcessingRepositoryImpl(contentDetectionService: Get.find<ContentDetector>(), documentCropService: Get.find<DocumentCropper>(), ...)`.

**Acceptance:** `grep -rn "abstract class\|abstract interface class" lib/features/processing lib/core/platform` returns the 3 new contracts; `ProcessingRepositoryImpl` constructor mentions no concrete service type; `flutter analyze` clean.

### 1.2 Fix the one real DIP break (G1)

**File:** `capture/presentation/actions/open_capture_dialog_action.dart:14`
- Remove `Get.find<CaptureController>()`; add `CaptureController` (or the 3 callbacks it uses) as a constructor parameter.
- `capture/presentation/bindings/capture_binding.dart` → pass it in at registration.

**Acceptance:** `grep -rn "Get.find" lib | grep -vE "/bindings/|/di/"` no longer lists `open_capture_dialog_action.dart` (only the 3 sanctioned page/widget lookups remain).

---

## Phase 2 — Contain the native dependencies (boundary translation)

> **AUDIT: N1, N2, N3 (MAJOR)** · Std §3 · Anti-Corruption-Layer ([Microsoft](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)).
> Wrappers exist but don't *contain* the plugin — raw `camera`/ML-Kit types flow through 19/10 files, including a shared `core` model. Translate at the boundary so plugin types stop at the wrapper.

### 2.1 Make `DetectionResult` plugin-free (N2) — highest leverage

**File:** `core/models/detection_result.dart`
- Replace `final List<Face>? faces;` and `final RecognizedText? recognizedText;` with plugin-free domain shapes: e.g. `final List<DetectedFace>? faces;` (a small value object holding `boundingBox` + contour points) and `final String? extractedText;` (+ block geometry if needed downstream).
- Map ML-Kit `Face`/`RecognizedText` → these domain types **inside** `ContentDetectionService` (and the realtime detection services), not in the model.

**Ripple:** `processing_repository_impl.dart:117-143` (face-rect/contour extraction) and `realtime_camera_controller.dart:7` consume the new domain types instead of `Face`.

**Acceptance:** `grep -rn "google_mlkit" lib/core` returns nothing; `detection_result.dart` imports no plugin.

### 2.2 Stop `camera` types leaking (N1)

- In `CameraSessionService` and the realtime/capture wrappers, expose domain-level frames/params instead of passing raw `CameraImage`/`ResolutionPreset`/`FlashMode`/`InputImageRotation` up to pages/configs/controllers.
- Convert `CameraImage → InputImage` **inside** the detection wrapper (it's the ACL "translate" step), not in widgets.

**Acceptance:** `grep -rln "package:camera" lib | wc -l` drops well below 19 (target: wrappers + frame factory only, not pages/controllers/configs).

### 2.3 Wrap `image_picker` (N3)

**Files to create/edit**
- `lib/core/platform/image_picker_gateway.dart` — `abstract interface class ImagePickerGateway { Future<String?> pickImage(...); Future<List<String>> pickMultiImage(...); }` + an impl wrapping the plugin.
- Edit `capture/presentation/controllers/capture_controller.dart:53-69` and `batch/presentation/controllers/batch_processing_controller.dart:2` to depend on the gateway (injected), not `ImagePicker` directly.

**Acceptance:** `grep -rn "package:image_picker" lib` shows only the gateway impl.

---

## Phase 3 — Close the testing gap  *(the most visible showcase win)*

> **AUDIT: B1, B2, B3, T1, T2 (BLOCKER/MAJOR)** · Std §16, §17.
> Mirror the **exemplary** `history` test pattern (`registerFallbackValue` in `setUpAll`, `when`/`verify`, both success+failure paths, `Get.reset()` in `tearDown`).

### 3.1 Test `ProcessingRepositoryImpl` (B3 — now possible after Phase 1)

**File to create:** `test/features/processing/data/repositories/processing_repository_impl_test.dart`
- Mock `ContentDetector`, `DocumentCropper`, `FileService`.
- Cover: face flow, document flow (+PDF), no-content → `DetectionFailure`, exception → `ProcessingFailure` mapping, working-copy cleanup on every path.

**Acceptance:** the repo impl has a test; success + each failure-mapping branch asserted.

### 3.2 Test `batch` (B2 — already injectable)

**Files to create** under `test/features/batch/`:
- `presentation/controllers/batch_processing_controller_test.dart` (mock `ProcessImage`/`SaveHistory`/`FileService`/`ModalService`; `Get.reset()` in tearDown).
- `services/batch_item_state_transitions_test.dart`, `batch_item_state_mutator_test.dart`, `batch_queue_initializer_test.dart`, `batch_run_metrics_tracker_test.dart`, `batch_history_mapper_test.dart` — these are pure; test directly.

**Acceptance:** `find test/features/batch -name '*_test.dart'` lists ≥6 files; all green.

### 3.3 Test `realtime` (B1 — start with the injected/pure units)

**Files to create** under `test/features/realtime/`:
- `presentation/controllers/realtime_camera_controller_test.dart` (fully injected — state transitions with all mocks).
- `services/realtime_face_geometry_normalizer_test.dart`, `realtime_frame_perf_tracker_test.dart`, and payload-transform tests for `realtime_preview_builder` (the pure record in/out parts).

**Acceptance:** realtime has its first tests; the normalizer + perf tracker + controller are covered.

### 3.4 Widget tests (T1)

**Files to create:** at least
- `test/features/history/presentation/pages/history_page_test.dart` — empty / error / list states.
- `test/features/batch/presentation/pages/batch_processing_page_test.dart` — running / done states.

**Acceptance:** `grep -rln "testWidgets" test | wc -l` ≥ 2.

### 3.5 Coverage gate / CI (T2)

**Files to create**
- `.github/workflows/ci.yml` — `flutter analyze` + `flutter test --coverage`, then a coverage gate (e.g. `very_good_coverage` action) on `lib/features/**/domain` and `lib/features/**/data`, excluding `*.g.dart`.
- (optional) `coverage_helper`/exclusions for generated files.

**Acceptance:** CI runs on push; coverage gate enforces domain+data; `*.g.dart` excluded.

---

## Phase 4 — Structure & SRP polish  *(strong, not blocking)*

> **AUDIT: A1, A2, A3, C1, M4, M8 + consolidation (§8)** · Std §4-S, §10.

### 4.1 Split `ProcessingRepositoryImpl` (A1, A2, A3)
- Extract `FaceAnnotationService` (from `_annotateFaces`, `:341-457`), `PdfGenerationService` (from `_generatePdf`), `OrientationService` (from `_restoreDocumentOrientation`/flip/mirror).
- Extract a shared `_runDocumentPipeline(...)` + `_buildResult(...)` used by both `processImage` and `processImageExternal` (kills the DRY duplication, `:40-309`).
- Inject the new services as **interfaces** (consistent with Phase 1).
**Acceptance:** `processing_repository_impl.dart` < ~200 LOC; no method > ~40 LOC; both entry points share one pipeline helper.

### 4.2 Relabel mis-filed view-models (C1, M4, M10)
- `realtime/services/realtime_overlay_state_store.dart` → make it the realtime `GetxController` (or fold into `RealtimeCameraController`), move under `presentation/`.
- Extract `FaceThumbnailStripPresenter` from `core/widgets/analysis/detected_faces_strip_state.dart:94-285` (logic out of the widget; cache service injected).
- Move `core/services/document_actions_presenter.dart` to a feature `presentation/`.
**Acceptance:** no class holding `.obs` state lives under a `services/` dir; the strip widget calls one presenter method.

### 4.3 Consolidate duplicated/over-split coordinators (§8)
- Merge `RealtimeRouteLifecycleCoordinator` + `CameraCaptureRouteLifecycleHelper` (verified near-identical, 102 LOC each) → one `core/CameraRouteLifecycleController`; delete the twin. Same for the duplicated `CameraLifecycleGuard` usage.
- Merge `BatchItemStateTransitions` + `BatchItemStateMutator` → `BatchItemStateManager`.
- Merge `RealtimeFrameProcessor` + `RealtimeDetectionPipelineCoordinator` (overlapping per-frame orchestration).
- Fold `CameraCaptureActionsHelper` (stateless, 78 LOC) back into its controller.
**Acceptance:** the two route-lifecycle files become one; service count drops; tests still green.

### 4.4 Symmetric mapping (M8)
- Extract a mapper for `ProcessingHistory → ProcessingResult` (`result_controller.dart:69-82`), mirroring `BatchHistoryMapper`.
**Acceptance:** no entity mapping inline in a controller.

---

## Phase 5 — Consistency quick-wins  *(low risk, interleave anytime)*

> **AUDIT: M1, M2, M3, M5, M6, E1, E2, E3 + nits** · Std §6, §10, §11, §13.

- [ ] **E1** — add `onLog: (e, st) => Log.error(...)` to the 4 guards in `history/data/repositories/history_repository_impl.dart:17,25,51,57`.
- [ ] **E2** — `native_corner_detection_service.dart:79,154` → return `Result<DocumentCorners?>` instead of degrading errors to `null`.
- [ ] **E3 / M6** — move `realtime_camera_controller.dart:248-270` capture IO into a service returning `Result`; add `Log` to the camera/realtime catches that only convert (`camera_capture_actions_helper.dart:47,71`, `realtime_stream_coordinator.dart:85`).
- [ ] **M1** — introduce `FaceRect`/`ContourPoint` value objects in `domain/entities/`; replace the inline records on `ProcessingResult`/`ProcessingHistory` (`:29-30`) and reuse the existing `face_thumbnail_builder.dart:11-16` typedefs everywhere.
- [ ] **M2** — append a one-line justification to the 5 `// ignore: avoid_slow_async_io` (`processing_repository_impl.dart:324,326`, `file_service.dart:62,64`, `pdf_raster_service.dart:80`).
- [ ] **M3** — rename `realtime_camera_controller.dart` fields `_framePipelineTrigger`/`_sessionLifecycleHelper` → `_streamCoordinator`/`_sessionCoordinator`/`_routeCoordinator`.
- [ ] **M5** — `history_detail_controller.dart:44`, `result_controller.dart:42` → capture `RouteArgumentFailure` into an observable error state instead of throwing in `onInit`.
- [ ] **nits** — n1 (`is`→`switch` in `processing_controller.dart:28`), n2 (`r`→`rect`), n3 (drop redundant section comments / extract helpers), n4 (throttled debug log on hot-path `catch (_)`), n6 (`lazyPut` the inline-`new`ed `DocumentActionsPresenter`).

**Acceptance:** each box ticked; `flutter analyze` clean; no `// ignore:` without justification.

---

## What this buys you (for the evaluator)

| Before | After |
|---|---|
| Service layer can't be mocked → 2 biggest features untested | Interfaces at the seams → repo + detection fully unit-tested |
| `camera`/ML-Kit types in 19/10 files incl. a `core` model | Plugin types stop at the wrapper; `core` is plugin-free |
| realtime + batch: 0 tests | controllers + pure services covered; coverage gate in CI |
| 501-LOC repo doing annotation/PDF/EXIF | thin `Result`-returning coordinator + focused collaborators |
| ~33 services, some duplicated verbatim | consolidated; every split justified by a real "reason to change" |

Net effect: the codebase moves from **"clearly understands Clean Architecture"** to **"reference implementation"** — the DIP seam closes, the native boundary is real, and the test suite proves the architecture instead of just asserting it.

---

## Suggested commit sequence

1. `refactor(processing): extract ContentDetector/DocumentCropper/CornerDetector interfaces` (Phase 1)
2. `fix(capture): inject CaptureController instead of Get.find` (G1)
3. `refactor(core): make DetectionResult plugin-free; translate ML-Kit at the boundary` (Phase 2)
4. `test(processing): cover ProcessingRepositoryImpl` (B3)
5. `test(batch): controller + pure services` · `test(realtime): controller + normalizer + perf` (B1/B2)
6. `test: widget tests for history/batch pages` + `ci: analyze + coverage gate` (T1/T2)
7. `refactor(processing): split annotation/PDF/orientation + share document pipeline` (Phase 4)
8. `refactor: consolidate duplicated lifecycle/batch coordinators` (§8)
9. `chore: consistency fixes (onLog, named types, // ignore justifications, naming)` (Phase 5)
