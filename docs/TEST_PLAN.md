# Test Plan — ImageFlow

> Written after the code-hardening pass (77 commits, architecture/quality/perf all reviewed). Goal: raise coverage from "domain + a few controllers" to "every layer that can break has a guard," then add CI. Ordered by **risk × current gap** — highest-value first.

**Baseline (current):** 203 tests, 22 test files. Unit-only; **0 widget tests, 0 integration tests, no CI.**

**Testing stack:** `flutter_test` + `mocktail` (already in use). Widget tests use `flutter_test`'s `testWidgets`; integration would add `integration_test` (only if we decide to).

---

## Coverage map (what exists vs what's missing)

| Feature | Controllers | Test files | State |
|---|---|---|---|
| history | 2 | 7 | ✅ well covered (usecases, repo, model, controller) |
| processing | 1 | 4 | ✅ good (entities, usecase, controller) |
| realtime | 1 | 2 | 🟡 pipeline + geometry only; controller/coordinators untested |
| result | 1 | 1 | 🟡 pdf_viewer only; ResultController untested |
| capture | 2 | 1 | 🟡 CaptureController only; CameraCaptureController + lifecycle untested |
| **batch** | 1 | **0** | 🔴 **zero tests** — most complex untested logic in the app |

**core:** error/, mappers/, lru_cache, pdf_raster, permission-mixin covered. Untested: camera_lifecycle_guard, app_image_cache, file_service, storage_service, modal_service.

---

## Phase 1 — Close the biggest gaps (unit, high value)

### 1.1 Batch — the #1 priority (currently 0 tests) 🔴
`BatchProcessingController` has the most untested branching logic in the app: sequential queue, stop-after-current, per-item retry/reselect, partial failure, progress callbacks, dispose-mid-run guards. Adversarial review flagged this area repeatedly.
- **`batch_processing_controller_test.dart`** — mock `ProcessImage`, `SaveHistory`, `ModalService`, `ImagePickerGateway`; assert:
  - all-success run → every item `success`, history saved N times, success snack
  - one item fails → that item `failed`, others succeed, warning snack, `failedCount` correct
  - `requestStop()` mid-run → stops after current, remaining stay `pending`, `isStopping`/`isRunning` reset
  - `retryFailed()` / `retryItem()` → only failed→pending, re-runs
  - overlapping `processPending()` blocked by `isRunning`
  - progress callback ignored after dispose (`isClosed`)
- **`batch_item_state_manager_test.dart`** — the transition/mutation helper (pure, easy, high value): pending→running→success/failed transitions, no-op when unchanged (the `_isSame` dedupe).
- **`batch_queue_initializer_test.dart`** — dedupe (LinkedHashSet), empty-path filtering, empty-input → error Result.

### 1.2 Realtime detection scheduler (pure, untested)
`RealtimeDetectionScheduler` is pure timing logic — trivial to test, currently only exercised indirectly.
- **`realtime_detection_scheduler_test.dart`** — `tryBegin*` respects interval + busy lock; `end*` releases; `tryTake*PanelSlot` throttles; `reset()` clears. Inject `DateTime` to control time.

### 1.3 Controllers with no test
- **`result_controller_test.dart`** — route-arg switch (ProcessingResult / ProcessingHistory / bad → failure state), `hasPdf`/`isFace`/`isDocument`, `resultFromHistory` path, PDF-viewer disposal in onClose.
- **`camera_capture_controller_test.dart`** — capture success → navigate; CameraException → failure state + log; `isCapturing` guard; onClose cleanup. (Camera plugin mocked.)

---

## Phase 2 — core helpers + missed data logic

- **`camera_lifecycle_guard_test.dart`** — begin/end busy lock, generation bump/invalidate/isCurrent, the `enabled:false` bypass.
- **`file_service_test.dart`** — relative↔absolute path construction, directory names (mock path_provider).
- **`content_detection_service` rotation fallback** — the 0/90/180/270 retry chain (if mockable without real ML Kit; else document why skipped).
- **`realtime_face_geometry_normalizer_test.dart`** — normalize rect/contour math, mirror compensation, primary-face selection (pure math, no frame needed).

---

## Phase 3 — Widget tests (first ones in the codebase)

Pick the widgets with real logic, not pure layout:
- **`camera_error_view_test.dart`** — permission vs generic icon, Open Settings only when permission + callback, Retry when canRetry/permission. (Just shared it to core — good first widget test.)
- **`batch_item_tile_test.dart`** — status→subtitle/icon/color mapping (the switch), error code formatting.
- **`document_info_strip_test.dart`** — "View Content" shown only when text present.
- Smoke test: each page builds without throwing given a mocked controller.

---

## Phase 4 — CI

- **`.github/workflows/ci.yml`** — on push/PR: `flutter analyze` (fail on any issue) + `flutter test` + optionally `--coverage` with a threshold. Pin Flutter 3.44.
- Add a coverage badge / `--coverage` artifact if desired.

---

## Explicitly out of scope (for now)
- **Full `integration_test`** (real-device flows) — high setup cost, needs a device/emulator; revisit only if the portfolio wants an end-to-end demo.
- **Golden tests** — brittle for a portfolio unless a specific pixel-stable widget justifies it.
- **Native channel tests** (corner detection, pdf raster native side) — can't unit-test the platform side; the Dart wrappers are already tested via mocks.

---

## Suggested order
1. **1.1 Batch** (biggest risk, zero coverage) — start here
2. 1.2 scheduler + 1.3 controllers (quick, pure/mockable)
3. Phase 2 core helpers
4. Phase 3 first widget tests
5. Phase 4 CI (lock it in so nothing regresses)

Each phase: run full suite green + analyze clean, commit per logical group. Target: no untested branching logic in batch/realtime/result; CI guarding every push.
