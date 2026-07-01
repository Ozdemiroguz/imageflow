# Realtime — Ideal Structure (De-fragmentation Plan)

> Root problem: `realtime` grew to **15 folders for 29 files** (~2 files/folder) — over-fragmentation, the opposite of clean. Each small concern got its own folder (`config/`, `converters/`, `coordinators/`, `state/`, `enums/`, separate `datasources/`+`services/`). This doc designs the **minimal, clean-architecture-correct** structure: 3 layers, only the role-folders that carry real weight, general classes lifted to `core/` where their *nature* is cross-cutting.

**Date:** 2026-07-01 · Companion to [FOLDER_CONVENTIONS.md](./FOLDER_CONVENTIONS.md).

**Guiding principles (the lesson learned):**
1. **3 layers first** (`domain` / `data` / `presentation`); add a sub-folder only when it holds ≥~3 files of one real role. A folder for 1-2 files is fragmentation, not structure.
2. **`core` = *nature* is cross-cutting**, not "used by 2+ features today." A general utility (image ops, NV21 conversion) belongs in core even if one feature uses it now — chasing today's consumer count is a churn trap.
3. **A small, documented imperfection beats an invented layer.** (Fowler/Metz: don't add abstraction/structure to avoid a minor coupling.)

---

## 1. Current (15 folders) → Ideal (target)

### The over-split folders and what happens to them

| Current | Files | Verdict | → Ideal |
|---|---|---|---|
| `config/` | 3 (config, scheduler, enum) | **DELETE the folder** — it's an invented 4th layer | scheduler is pure logic → `data/`; config+enum → see §2 |
| `data/converters/` | 2 (nv21, input_image_factory) | **DELETE** — 2 files, generic frame→InputImage | these are **general camera/ML utilities** → lift to `core/` (their nature is cross-cutting; today only realtime, but they're not realtime-specific business) |
| `data/datasources/` + `data/services/` | 2 + 5 | **KEEP** — this is a *real* clean-arch role split: datasource = outer-world boundary (camera SDK), service = inner detection logic. Not fragmentation. | keep both |
| `presentation/*` (all) | — | **DO NOT TOUCH** — `controllers/coordinators/pages/widgets/bindings` are real roles; `state/enums/models` are conventional, familiar folder names a senior won't read as fragmentation. Single-file today, natural home as the feature grows. | keep every one |

### Scope: only 2 real problems, both on the data/config side. presentation/ is untouched.
```
realtime/
├── data/
│   ├── datasources/         (face + ocr ML-Kit wrappers)  ← KEEP
│   └── services/            (pipeline, normalizer, perf, preview + scheduler moved in)  ← KEEP
└── presentation/            ← UNTOUCHED (config + enum move IN here, at root)
    ├── controllers/  coordinators/  pages/  widgets/  bindings/
    ├── state/  enums/  models/   ← conventional, familiar; NOT fragmentation; keep as-is
    ├── capture_realtime_config.dart          ← moved from config/
    └── realtime_native_rotation_strategy.dart ← moved from config/
```
Gone: `config/` (invented layer) and `data/converters/` (generic utils → core). Everything else stays.

---

## 2. The config problem — solved WITHOUT a config layer

`CaptureRealtimeConfig` (SDK-bound), `RealtimePipelineCoordinator` (pure scheduler), and the rotation enum caused the whole `config/` mess. Resolution:

- **`RealtimePipelineCoordinator`** (pure frame-scheduling logic, no framework) → it's **detection logic** → `data/`. Rename to `RealtimeDetectionScheduler` for clarity (it schedules/throttles detections).
- **`CaptureRealtimeConfig`** + rotation enum → this is a **realtime platform preset** (camera resolution/format/rotation + timing + labels). It's consumed by both data (4 fields) and presentation (most fields). **Keep it as ONE config object in `presentation/`** (its natural home — presentation reads ~18 of 22 fields), and pass the **4 fields data needs** into the data classes as plain constructor parameters (not the whole config). That removes the data→presentation config coupling without splitting the config into 3 classes (which was over-engineering — presentation uses almost all of it anyway).

> **The remaining data→presentation edge** (pipeline coordinator writes overlay state) is a **separate, documented issue** — a real but small coupling. Fixing it properly means inverting the overlay writes (data returns results, presentation applies them), which is a large rewrite of a 411-line, **untested** hot-path file. **Defer to after realtime has tests.** Documenting one known coupling is cleaner than inventing a neutral layer to hide it.

---

## 3. General classes to lift to `core/` (nature is cross-cutting)

| Class | Why core | Note |
|---|---|---|
| `android_nv21.dart` (CameraImage→NV21) | Generic camera-frame conversion, not realtime business | Only realtime uses it today, but its *nature* is a shared camera utility → `core/utils/` or `core/platform/` |
| `realtime_input_image_factory.dart` | Generic CameraImage→ML-Kit InputImage | Same — a camera/ML bridge utility. (Note: it's named "realtime" but the logic is generic; rename to `camera_input_image_factory`.) |

These two were moved *out* of core last round on the "1 feature" rule — which this doc rejects. They should go **back** to core because they're cross-cutting *by nature*.

**Not lifted:** the ML-Kit detectors (`face_detection`, `ocr_gate`), preview builder, detection pipeline — these ARE realtime-specific (fast-frame, realtime tuning) → stay in `realtime/data/`.

---

## 4. Concrete move list (behavior-preserving, no new invented layers)

1. **Delete `config/`:**
   - `realtime_pipeline_coordinator.dart` (pure scheduler) → `data/services/`.
   - `capture_realtime_config.dart` + `realtime_native_rotation_strategy.dart` (enum) → `presentation/` root (config's natural home; presentation reads ~18/22 fields).
   - Where `data` classes currently read config fields, pass those specific fields as plain constructor params (removes the data→presentation config coupling).
2. **Delete `data/converters/`:** lift `android_nv21` + `realtime_input_image_factory` to `core/` (cross-cutting camera/ML utils).
3. **Keep everything else:** `data/datasources` vs `data/services` (real role split), all of `presentation/`.

**Result:** 2 folders removed (`config/`, `data/converters/`), no invented layers, generic camera utils in core, one documented data→presentation overlay-write edge deferred to post-tests.

---

## 5. One-paragraph rationale

The fragmentation came from treating every minor placement question as needing its own folder, and from applying "core = used by 2+ features" mechanically (a churn trap). The fix is to collapse back to **3 layers + only weight-bearing role-folders**, lift the genuinely-general camera utilities to `core/` by their *nature* (not their current consumer count), keep the realtime config as one presentation object (passing data only the fields it needs), and **document** the single remaining data→presentation coupling rather than inventing a neutral layer to hide it — deferring its proper (large, hot-path) fix until realtime has a test safety net.
