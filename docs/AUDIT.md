# ImageFlow — Architecture & Code Audit

> A systematic review of the `imageflow` codebase against [ENGINEERING_STANDARDS.md](./ENGINEERING_STANDARDS.md).
> Every finding cites `path:line`, the violated rule, a severity, and a fix. Strengths are recorded as **PRAISE** so the report reflects the codebase honestly.

**Audited:** `imageflow/` (210 `lib/` Dart files) · **Against:** ENGINEERING_STANDARDS.md (18 sections) · **Date:** 2026-06-30
**Method:** machine checks (`flutter analyze`, dependency-rule greps, import maps) + 6 parallel dimension audits (architecture/SOLID, error handling, GetX/DI, clean code, widgets/perf, testing) + a dedicated service-layer & native-dependency study. Authoritative-source research backs the standard and the native-dependency section.

---

## Severity legend

| | Meaning |
|---|---|
| 🔴 **BLOCKER** | Must fix before this is a credible showcase. |
| 🟠 **MAJOR** | Real violation of an accepted principle; fix recommended. |
| 🟡 **MINOR** | Small/peripheral deviation; fix when convenient. |
| ⚪ **NIT** | Cosmetic/stylistic. |
| 🟢 **PRAISE** | Done well; keep. |

---

## 1. Executive Summary

**ImageFlow is a genuinely above-portfolio-grade codebase.** The hard, easy-to-get-wrong things are right: the Clean Architecture dependency rule holds (zero forbidden imports in `domain/`, presentation never imports `data/`), the repository pattern is correctly inverted for both real data features, error handling uses a sealed `Result`/`Failure` pair consumed by exhaustive `switch`, GetX's service-locator risk is genuinely neutralized (`Get.find()` appears outside the composition root in only 4 places), and `flutter analyze` is **completely clean** against a strict 70+-rule lint set. The widget/performance layer (isolate offload, bounded image caches, `RepaintBoundary`, lazy lists, rigorous camera/ML-Kit disposal) is mature.

**Two systemic weaknesses are the gap between "very good" and "reference,"** and they share a single root cause:

1. **The infrastructure/service layer never applies Dependency Inversion.** No service has an interface; there is no `datasources/` layer. Native wrappers are injected as concrete types — which is exactly why the most complex data unit (`ProcessingRepositoryImpl`, 501 LOC) and the detection services are **untestable without a real device**, and therefore untested.
2. **Test coverage collapses outside `history`/`processing`/`core`.** The two largest features — **`realtime` (~4,200 LOC) and `batch` (~1,487 LOC) — have zero tests**, no widget tests exist anywhere, and there is no coverage gate / CI.

A third theme, raised directly by the owner, is answered in [§9 Service Layer & Native Dependencies](#9-service-layer--native-dependencies): the high service count is **only ~30% explained by native dependencies**; the rest is presentation/lifecycle coordination, some of it duplicated almost verbatim across `capture` and `realtime`.

### Scorecard

| Dimension | Grade | One-line |
|---|---|---|
| Dependency rule / layering | **A** | Holds at the macro level; verified by grep. |
| Repository pattern | **A−** | Correct for processing+history; realtime/capture/batch are presentation+services. |
| Error handling (`Result`/`Failure`) | **A** | Core is exemplary; peripheral camera/storage catches drop logging. |
| GetX discipline & DI | **A−** | Constructor injection near-universal; one real DIP break. |
| **DIP at the service layer** | **C** | No interfaces, no `datasources/`; blocks testing. |
| Clean code / Dart-3 idioms | **A−** | Idioms used as default; a few oversized methods + DRY gap in the repo. |
| Widgets / performance | **A** | Above showcase grade; only minor rebuild-scope nits. |
| **Testing** | **C** | History/core exemplary; realtime+batch zero; no widget tests; no CI. |
| Lint hygiene | **A** | `flutter analyze` clean; 5 unjustified `// ignore:`. |

---

## 2. Machine Checks (ground truth)

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** (strict lint set + `strict-casts`/`strict-raw-types`). |
| Forbidden imports in `domain/` (flutter/get/hive/mlkit/camera/pdf) | ✅ **None** — domain is pure Dart. |
| `presentation/` importing `data/` | ✅ **None**. |
| `Get.find()` outside `bindings/`+`di/` | ⚠️ **4** sites (analyzed in §5). |
| `abstract class` in any service dir | ❌ **Zero** (DIP gap, §6/§9). |
| `datasources/` directory | ❌ **Absent** (§9). |
| ML Kit types in shared `core/` model | ❌ `core/models/detection_result.dart:1-2,16-17` exposes `List<Face>?` + `RecognizedText?`. |
| `// ignore:` lines | ⚠️ **5**, none with the required justification (§4). |
| TODO/FIXME/HACK markers | ✅ **0**. |
| Commented-out code | ✅ **0**. |
| Test files vs lib files | ⚠️ **18 vs 210**; realtime=0, batch=0. |

---

## 3. Findings by Severity (top of the list = fix first)

### 🔴 BLOCKER

- **B1 — `realtime/` has zero tests.** `lib/features/realtime/**` (~24 files, ~4,200 LOC) including the single most complex unit `realtime/services/realtime_preview_builder.dart` (537 LOC) and `realtime/presentation/controllers/realtime_camera_controller.dart` (363 LOC, *fully constructor-injected and trivially testable*). — Std §16 ("DON'T ship a feature whose use cases/repository are untested") + §17. — **Fix:** unit-test the pure/injected units first (controller state transitions, geometry normalizer, frame perf tracker, payload transforms).
- **B2 — `batch/` has zero tests.** `lib/features/batch/**` (~1,487 LOC) including `batch/presentation/controllers/batch_processing_controller.dart` (312 LOC) and **five pure, trivially-testable** service classes (`batch_item_state_transitions`, `batch_run_metrics_tracker`, `batch_item_state_mutator`, `batch_history_mapper`, `batch_queue_initializer`). The controller is fully constructor-injected — testable today with `mocktail` exactly like `history_controller`. — Std §16. — **Fix:** mirror the `history` test pattern.
- **B3 — `ProcessingRepositoryImpl` is untested** (`processing/data/repositories/processing_repository_impl.dart`, 501 LOC, one of only two repo impls). — Std §16 ("100% on `domain/` and `data/`", "unit-test every repository impl with mocked datasources/services"). Root cause is **D1** (its collaborators are concrete, so the ML-Kit/isolate paths can't be mocked). — **Fix:** depends on D1; once detection/crop are abstracted, test success + every failure-mapping path.

### 🟠 MAJOR

- **D1 — No Dependency Inversion in the service layer (systemic).** Zero `abstract class` across all service dirs; no `datasources/`. Every collaborator is injected concretely: `DocumentCropService(NativeCornerDetectionService)`, `ProcessingRepositoryImpl(FileService, ContentDetectionService, DocumentCropService)`, the realtime services, etc. — Std §4-D, §9, §16 ("if a use case can't be unit-tested without ML Kit, the dependency inversion is broken"). This is the **root cause of B3** and most of the testability gap. — **Fix:** extract interfaces for the seams that matter first — `ContentDetector`, `DocumentCropper`, `CornerDetector`, plus `CameraDataSource`, `FaceDetectionDataSource`, `TextRecognitionDataSource`; bind interface→impl in bindings. (Leaf infra like `FileService` can stay concrete.)
- **N1 — `camera` plugin leaks across 19 files.** `CameraSessionService` wraps the *controller lifecycle* only; `CameraImage`/`ResolutionPreset`/`FlashMode`/`InputImageRotation` flow raw through pages, configs, and ~8 realtime services. — Std §3 (anti-corruption boundary) + native-dep research (ACL: wrap once, translate at the boundary). — **Fix:** map camera types to domain records inside the wrapper; stop passing raw plugin types upward.
- **N2 — ML Kit types leak into a shared `core/` model.** `core/models/detection_result.dart:1-2,16-17` exposes `List<Face>?` and `RecognizedText?` as public fields, consumed by the realtime controller (`realtime_camera_controller.dart:7`) and the repo. A `core` model is the worst binding site — it forces ML Kit onto every feature touching detection. — Std §3. — **Fix:** map `Face`/`RecognizedText` to plugin-free domain types inside the detection services; make `DetectionResult` plugin-free.
- **N3 — `image_picker` has no wrapper.** Imported directly in `batch_processing_controller.dart:2` and `capture_controller.dart:4` — plugin IO inside controllers. — Std §7/§8 (no IO in controllers). — **Fix:** introduce `ImagePickerGateway`, inject it.
- **A1 — `ProcessingRepositoryImpl.processImage` god-method.** `processing_repository_impl.dart:40-216` (~177 lines) inlines file copy, EXIF mirror correction, branch selection, ML-Kit face-rect/contour extraction (`:117-143`), thumbnail + history assembly. — Std §4-S, §10 (>~40-line flag). — **Fix:** extract `FaceAnnotationService`, `PdfGenerationService`, `OrientationService`; the repo becomes a thin `Result`-returning coordinator.
- **A2 — `_annotateFaces` does too much.** `processing_repository_impl.dart:341-457` (116 lines): isolate setup, contour math, crop/grayscale, contour masking, border drawing, 64-segment oval fallback. — Std §4-S, §10. — **Fix:** extract `_resolveFaceBounds`, `_drawContourBorder`, `_drawOvalBorder`, `_compositeOvalMask`.
- **A3 — DRY: `processImage` vs `processImageExternal`.** `processing_repository_impl.dart:40-309` — both share id/uuid, copy-to-original, working-copy scaffold, `try/finally`+`_safeDeleteFile`, document-crop + `_restoreDocumentOrientation`, PDF gen, thumbnail, file-size, `ProcessingResult` assembly. `processImageExternal` ≈ the document branch of `processImage`. — Std §10 (DRY). — **Fix:** extract a shared `_runDocumentPipeline(...)` and `_buildResult(...)`.
- **G1 — Real DIP break: `Get.find()` inside an injected collaborator.** `capture/presentation/actions/open_capture_dialog_action.dart:14` calls `Get.find<CaptureController>()` inside a non-widget class that is itself injected (and already receives `ModalService` by constructor). `CaptureController` becomes a hidden, unmockable dependency. — Std §4-D, §7 ("DON'T call `Get.find()` from inside a controller/use case"). — **Fix:** inject `CaptureController` (or its callbacks) via the constructor; register in `capture_binding.dart`.
- **E1 — `HistoryRepositoryImpl` guards drop `onLog`.** `history/data/repositories/history_repository_impl.dart:17,24,50,57` — all four `Result.guard` calls supply `onError` but omit `onLog`; storage errors are converted but never logged. — Std §6 ("generic IO catch MUST log and convert, never discard"). — **Fix:** add `onLog: (e, st) => Log.error(...)`, mirroring `ProcessingRepositoryImpl`.
- **E2 — `native_corner_detection_service` degrades real errors to `null`.** `core/services/native_corner_detection_service.dart:79-86,154-157` — generic `catch (e)` logs but returns `null`, collapsing "no document found" and "platform error" into one signal. — Std §6 ("DON'T return `null` to signal failure"). — **Fix:** return `Result<DocumentCorners?>` (Ok(null)=no rectangle, Error=failure).
- **E3 — Camera IO + its try/catch live in a presentation controller.** `realtime/presentation/controllers/realtime_camera_controller.dart:248-270` — `capture()` runs `stopImageStream`/`takePicture` and catches `CameraException`/`Object` (converts to `CameraFailure` but doesn't log). Near-duplicate of the correctly-placed `camera_capture_actions_helper.dart`. — Std §6/§7/§8. — **Fix:** move capture IO into a service returning `Result`; add logging.
- **C1 — Mis-filed presentation view-model under `services/`.** `realtime/services/realtime_overlay_state_store.dart` holds GetX-reactive state (`.obs`, `Rxn`) and imports presentation models — it's a ViewModel, not a service (its own header admits it). — Std §2.1/§8. — **Fix:** make it the realtime `GetxController` (or fold into `RealtimeCameraController`); see N7.
- **T1 — No widget tests anywhere.** No `testWidgets`/`pumpWidget` in the suite. Non-trivial pages (history list, batch progress, realtime preview) have no loading/error/empty/success coverage. — Std §16. — **Fix:** start with history (empty/error/list) and batch.
- **T2 — No coverage tooling / CI.** No `.github/`, no `melos.yaml`, no `very_good_coverage`/`--min-coverage`. The "100% on domain/data, enforced in CI" rule is unenforced. — Std §16/§17. — **Fix:** add a CI workflow running `flutter test --coverage` gating domain/data, excluding `*.g.dart`.

### 🟡 MINOR

- **M1 — Inline records as domain-entity fields.** `processing/domain/entities/processing_result.dart:29-30` and `history/domain/entities/processing_history.dart:29-30` type fields as `List<({int left,int top,int width,int height})>` and `List<List<({int x,int y})>>`. — Std §11 ("PREFER a named type when the shape is part of a domain entity / public API"). Note `face_thumbnail_builder.dart:11-16` already defines `FaceRectData`/`FaceContourPoint` typedefs. — **Fix:** introduce `FaceRect`/`ContourPoint` value objects in `domain/entities/` and reuse everywhere.
- **M2 — `// ignore:` without justification.** `processing_repository_impl.dart:324,326`, `file_service.dart:62,64`, `pdf_raster_service.dart:80` — 5 `// ignore: avoid_slow_async_io`, none justified. — Std §13/§1. — **Fix:** append a one-line justification to each.
- **M3 — Name/type mismatch in realtime controller.** `realtime_camera_controller.dart` fields `_framePipelineTrigger` (type `RealtimeStreamCoordinator`), `_sessionLifecycleHelper` (type `RealtimeCameraSessionCoordinator`) — "Trigger"/"Helper" names contradict "Coordinator" types. — Std §10. — **Fix:** rename to `_streamCoordinator`/`_sessionCoordinator`/`_routeCoordinator`.
- **M4 — Logic in a shared widget.** `core/widgets/analysis/detected_faces_strip_state.dart:94-285` — the widget `State` runs a multi-strategy isolate thumbnail pipeline + cache orchestration. (Heavy work *is* isolate-offloaded — good — but the *orchestration* belongs in a service.) Also the lone `Get.find()` in a reusable widget (`:12`). — Std §7/§8/§14. — **Fix:** extract a `FaceThumbnailStripPresenter` taking the cache service by constructor.
- **M5 — Two `onInit()` methods throw into presentation.** `history_detail_controller.dart:44` and `result_controller.dart:42` `throw const RouteArgumentFailure(...)` instead of capturing into an observable error state. — Std §6. — **Fix:** set an error-state field and render it (mirror `processing_controller`).
- **M6 — Camera/realtime service catches convert-without-logging.** `camera_capture_actions_helper.dart:47,71`, `realtime_stream_coordinator.dart:85` convert to `CameraFailure` but don't `Log`. — Std §6. — **Fix:** add `Log.error/warning`.
- **M7 — Over-broad `Obx` + per-rebuild copy (batch).** `batch/presentation/pages/batch_processing_page.dart:14` wraps the whole `Scaffold` reading only `isRunning`; `batch_body.dart:38-58` rebuilds the whole `ListView` on `isRunning` change and allocates `List.unmodifiable(controller.items)` every build. — Std §14/§15. — **Fix:** scope `Obx` to the widgets that read `running`; iterate `controller.items` lazily in `itemBuilder`.
- **M8 — Inline mapping in `ResultController`.** `result_controller.dart:69-82` maps `ProcessingHistory → ProcessingResult` in the controller, asymmetric with the existing `BatchHistoryMapper`. — Std §17. — **Fix:** extract a mapper.
- **M9 — `image_picker` in controllers (data acquisition).** `capture_controller.dart:53-69` (covered by N3) — controller touches the plugin directly. — Std §7/§8.
- **M10 — `DocumentActionsPresenter` misfiled in `core/services/`.** It's pure presentation orchestration (overlay + failure-snack). — Std §5. — **Fix:** move to a feature `presentation/`.
- **M11 — `realtime`/`capture`/`batch` have no `domain/data` layers.** Acceptable per §2.2 (device-IO features; batch reuses processing use cases) — but `realtime` does enough detection orchestration that a `DetectRealtimeContent` contract would match the project's own "domain is mandatory" stance. — Std §2.2 (recorded as acceptable-with-caveat).

### ⚪ NIT

- **n1** — `is`-check on sealed type: `processing_controller.dart:28` `isDetectionError => failure.value is DetectionFailure` (prefer `switch`). Std §6/§11.
- **n2** — Single-letter `r` for a rect: `processing_repository_impl.dart:118`, `document_crop_service.dart:86`. Std §10.
- **n3** — Redundant section comments restating the next line: `processing_repository_impl.dart:171,179,269,277` ("// Generate thumbnail", …) — signal to extract named helpers. Std §10.
- **n4** — `catch (_)` without log on hot frame paths: `realtime_preview_builder.dart:95,189` (perf-justified, but add throttled debug log). Std §6.
- **n5** — `Widget _build…` helper leaves: `preview_loading_skeleton.dart:66,93,200`, `history_thumbnail.dart:33` (static skeletons — defensible). Std §14.
- **n6** — `DocumentActionsPresenter` `new`-ed inline in two bindings (`result_binding.dart:14`, `history_detail_binding.dart:14`) instead of `lazyPut` once. Std §9.
- **n7** — `bool? capturedWithFrontCamera` is a (named) flag arg gating branches: `processing_repository.dart:13` etc. Defensible; a `CaptureSource` enum/value object would be cleaner and would type-safe the `'capturedWithFrontCamera'` magic string at `realtime_camera_controller.dart:259`. Std §10/§12.

---

## 4. PRAISE — what the evaluator should notice

- **Error-handling core is textbook.** `core/error/result.dart` (`sealed Result<T>` + `guard` with mandatory `onError`), `failures.dart` (`sealed Failure` with stable `code`s), and `failure_ui_mapper.dart:7-56` — a single **exhaustive, `default`-free** `switch` over `Failure` (adding a subtype is a compile error). Every repo/use-case returns `Future<Result<T>>`; every controller consumes it via `case Ok()/Error()`. This is the standard implemented, not cosmetically.
- **Dependency rule genuinely holds.** Verified by grep: `domain/` imports no framework; presentation never imports `data/`. The two real data features invert correctly (`Get.lazyPut<ProcessingRepository>(() => ProcessingRepositoryImpl(...))`).
- **GetX service-locator risk is neutralized.** Constructor injection is near-universal across controllers, use cases, repos, and services; `Get.find()` is confined to the composition root plus 3 sanctioned page/widget lookups.
- **Lifecycle/disposal is rigorous.** `RealtimeCameraController.onClose` removes the lifecycle observer, cancels the frame timer, shuts the camera session, and `close()`s both ML-Kit detectors; `isClosed`-after-`await` guards are consistent. No stream/worker leaks found.
- **Performance is mature.** Heavy pixel work offloaded via `Isolate.run` (`processing_repository_impl.dart:347`, `document_crop_service.dart:50`, `realtime_preview_builder.dart:90`); `image_cache_policy_service.dart` is bounded + memory-pressure-aware; realtime overlays use `RepaintBoundary` + tight `Obx`; lists are uniformly `.builder`.
- **The three `MethodChannel` natives are an exemplary anti-corruption layer.** `native_corner_detection_service`, `pdf_external_open_service`, `pdf_raster_service` — each channel wrapped exactly once, returning typed values / `Result`. This is the pattern the *plugins* should follow.
- **`history` + `core/error` tests are exemplary.** `registerFallbackValue` in `setUpAll`, `when`/`verify`/`.called(1)`, **both success and failure paths**, `Get.reset` between tests, exhaustive-`switch` assertions. The author demonstrably *knows how* to test to the standard — which makes the realtime/batch gap a missing-effort gap, not a skill gap.
- **`flutter analyze` is clean** against a strict, hand-curated lint set with `strict-casts`/`strict-raw-types`. Zero TODO/FIXME, zero commented-out code.

---

## 5. The four `Get.find()` sites (verdicts)

| Site | Verdict |
|---|---|
| `realtime_page.dart:28`, `camera_capture_page.dart:32` | 🟡 MINOR — a page reaching for its own route-scoped controller (sanctioned GetX pattern). Optional fix: `GetView<T>`. |
| `detected_faces_strip_state.dart:12` | 🟡 MINOR — reusable widget grabbing an app-singleton cache service; least defensible of the three (hidden dep). Prefer constructor injection. |
| `open_capture_dialog_action.dart:14` | 🟠 **MAJOR (G1)** — service-locator inside an injected non-widget collaborator. The one real DIP break. |

---

## 6. Testing — coverage map

| Layer / Feature | Tests? | Quality |
|---|---|---|
| `core/error` (Result, Failure, UI mapper) | ✅ | Strong — error paths, guard, exhaustive switch |
| `core/services` (pdf_raster only) | ✅ (1) | Present; rest of core untested |
| `history` — usecases (3/3), repo impl, model, entity, controller | ✅ | **Exemplary** |
| `processing` — usecase `process_image` | ✅ | Excellent |
| `processing` — **repo impl** (501 LOC) | ❌ | **Missing (B3)** — blocked by D1 |
| `capture`/`result` — controllers | ✅ | Present |
| **`realtime` — all** (~4,200 LOC) | ❌ | **ZERO (B1)** |
| **`batch` — controller + 5 services** (~1,487 LOC) | ❌ | **ZERO (B2)** |
| Widget tests | ❌ | **None (T1)** |
| Coverage / CI | ❌ | **None (T2)** |

**Top untested high-risk units:** `realtime_preview_builder.dart` (537), `realtime_camera_controller.dart` (363, *injected — easy*), `realtime_camera_session_coordinator.dart` (334), `batch_processing_controller.dart` (312, *injected — easy*), `realtime_detection_pipeline_coordinator.dart` (278), `realtime_overlay_state_store.dart` (231), plus `processing_repository_impl.dart` (501).

---

## 7. Suggested Remediation Order

1. **D1 → B3** — Extract interfaces for `ContentDetector`/`DocumentCropper`/`CornerDetector` (+ camera/ML-Kit data sources), bind interface→impl, then unit-test `ProcessingRepositoryImpl`. *One change unblocks the biggest testability hole.*
2. **B1 + B2** — Test the already-injected realtime/batch controllers and the pure batch/realtime services (low friction, high coverage gain).
3. **N1–N3** — Map plugin types at the wrapper boundary; make `core/models/detection_result.dart` plugin-free; wrap `image_picker`. *Removes ~25 of the leak sites.*
4. **A1–A3** — Extract the annotation/PDF/orientation collaborators and the shared document pipeline from `ProcessingRepositoryImpl`.
5. **T1 + T2** — Add widget tests for history/batch + a coverage-gated CI workflow.
6. **G1, E1–E3, C1, M-series** — Consistency fixes (logging, the one DIP break, mis-filed view-models, naming, `// ignore:` justifications).

---

## 8. Service Layer & Native Dependencies

> Directly answering the question: *"There are a lot of services — is that because of native dependencies, and should they be merged?"*

**Short answer:** Only partly. Of **~33 service classes, ~10 are genuine native/plugin/channel wrappers.** The rest (~14 presentation/lifecycle coordinators + ~9 orchestration helpers) have nothing to do with native code — and several are duplicated almost verbatim across `capture` and `realtime`. So the count is **a smell of over-fragmentation plus a missing abstraction layer**, not a healthy consequence of native complexity.

### What native deps *do* justify (keep separate)
Per Uncle Bob's SRP — *"gather together things that change for the same reasons; separate things that change for different reasons"* ([SRP](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html)) — **different SDKs have different reasons to change, so they stay separate:** ML-Kit-face (`RealtimeFaceDetectionService`) vs ML-Kit-text (`RealtimeOcrGateService`) vs camera (`CameraSessionService`) vs corner-detection channel (`NativeCornerDetectionService`) vs PDF channels. Independent lifecycles (`FaceDetector.close()` vs `TextRecognizer.close()`), independent failure modes. **This split is correct.**

### Native-dependency leak map (the real problem)

| Plugin | Direct import sites | Contained? |
|---|---|---|
| `path_provider` | 1 (`file_service.dart`) | ✅ Exemplary |
| `pdf` | 1 (`processing_repository_impl.dart`) | ✅ single-site |
| MethodChannel ×3 | 1 each | ✅ **exemplary ACL** |
| `permission_handler` | 2 | ⚠️ one widget leak |
| `image_picker` | 2 (controllers) | ❌ **no wrapper (N3)** |
| `google_mlkit_text_recognition` | 4 | 🟡 leaks into `core` model |
| `hive_ce` | 5 (history data layer) | ✅ acceptable |
| `google_mlkit_face_detection` | 10 | ❌ **leaks into `core` model (N2)** |
| **`camera`** | **19** | ❌ **wrapped controller only; types leak everywhere (N1)** |

The principle (from authoritative research — the **Anti-Corruption Layer**, [Microsoft](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer); plugins are *details* in the outer ring, [Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)): **wrap each external once behind an interface you own, and translate its types into your domain types at the boundary.** The 3 channels do this; the plugins do not — the camera/ML-Kit wrappers exist but *don't actually contain the dependency* because raw `CameraImage`/`Face`/`RecognizedText` flow past them (19/10 files, including a shared `core` model).

### Consolidation — concrete merges

| Merge | Why |
|---|---|
| `RealtimeRouteLifecycleCoordinator` **=** `CameraCaptureRouteLifecycleHelper` | **Verified near-identical** (102 LOC each; diff is only the class/constructor name). Extract one `CameraRouteLifecycleController` in `core/`, delete the twin. Same for the duplicated `CameraLifecycleGuard` usage. |
| `BatchItemStateTransitions` + `BatchItemStateMutator` | One concept ("change a batch item's state"): callers always compute-then-apply. 58+29 LOC, always change together, no independent reuse. → `BatchItemStateManager`. |
| `RealtimeFrameProcessor` + `RealtimeDetectionPipelineCoordinator` | Overlapping per-frame orchestration with a fuzzy boundary; forces the controller to wire both. |
| `RealtimeOverlayStateStore` → fold into `RealtimeCameraController` | It's reactive view-state (a ViewModel), not a service (C1). |
| `CameraCaptureActionsHelper` → back into its controller | 78 LOC, stateless, just flash + take-picture. |

**Keep split:** the native SDK wrappers above; `FileService`/`StorageService`/`PermissionService` (three different plugins, one each); `ContentDetectionService` vs `DocumentCropService` (detect vs crop — different stages/outputs).

### Target model for services
1. Add `lib/core/platform/` (or per-feature `data/datasources/`) and give **every native wrapper an abstract interface**, bound interface→impl in bindings. *(Fixes D1; unblocks B3 and most testing.)*
2. **Translate plugin types at the wrapper boundary** so `Face`/`RecognizedText`/`CameraImage` never reach `core`/presentation; make `DetectionResult` plugin-free. *(N1, N2.)*
3. **Wrap `image_picker`** in one gateway. *(N3.)*
4. **Collapse the duplicated lifecycle/route coordinators** into one shared `core/` pair.
5. **Move per-frame orchestration into use cases**; make `RealtimeOverlayStateStore` the realtime controller; merge the two batch-state services.

> **Verdict on the owner's question:** the native split that exists is *correct and should stay*, but "many services" is mostly **over-fragmented coordinators + a missing interface layer**, not native complexity. The fix is to add the abstraction layer (interfaces + boundary translation) and merge the ~5 coordinator groups above — after which both the service count and the testability gap shrink together.

---

## 9. Closing Verdict

This codebase would read, to a strict technical evaluator, as the work of someone who understands Clean Architecture rather than someone who copied a folder template: the layer boundaries are real and grep-provable, the error model is sealed-type-correct, GetX's worst tendencies are actively disciplined, and the performance work (isolates, bounded caches, repaint isolation) is beyond typical portfolio quality. The two things standing between it and a reference-grade showcase are **a missing service-layer abstraction (interfaces + boundary translation)** — which is also why **the two biggest features are untested**. Both are concentrated, well-understood, and fixable along the order in §7; none are architectural dead-ends. Fix the DIP seam and the realtime/batch tests, and the "very good" becomes "reference."
