# Native Dependency Strategy

> Two questions drove this doc: **(1)** "is a bare native `service` inside a feature correct, or should every native/SDK dependency get a proper layered structure?" and **(2)** "shouldn't these native wrappers live in `core/` instead of a feature?"
>
> Answered with evidence (a complete per-SDK usage map) + the placement rule + the honest "don't force the wrong abstraction" caveat.

**Date:** 2026-06-30 · Companion to [SERVICE_PLACEMENT.md](./SERVICE_PLACEMENT.md), [REALTIME_NATIVE_BOUNDARY.md](./REALTIME_NATIVE_BOUNDARY.md).

---

## 1. The two rules that decide every native dependency

**Rule A — layer by imports.** A class wrapping a native SDK/plugin is *infrastructure* → it belongs in a **`data/`** folder (feature-scoped) or **`core/`** (cross-feature), never in `domain/` or `presentation/`. ([SERVICE_PLACEMENT §1](./SERVICE_PLACEMENT.md); official Flutter: *"Services… wrap an external API… platform plugins"*.)

**Rule B — core vs feature = count the consumers.** Used by **≥2 features → `core/`**; used by **exactly one feature → that feature's `data/`**. (Code With Andrea: `core/` is for code *"truly shared across features"*; Reso Coder pulls *"anything shared between multiple features into the core folder."*)

**The caveat (Fowler / Sandi Metz):** sharing a *home* (one folder) is not the same as sharing an *implementation* (one class). Two features using the same SDK for **different purposes** should share the SDK's neutral infrastructure but keep their purpose-specific wrappers — forcing them into one class is *"the wrong abstraction,"* which is more costly than duplication.

---

## 2. Complete native-dependency map (measured)

| SDK / native | Consuming features | Shared infra in `core/`? | Correct home | Status |
|---|---|---|---|---|
| `camera` | capture, realtime (**2**) | ✅ `CameraSessionService`, `realtime_input_image_factory`, `android_nv21` | core (shared) + per-feature use | ✅ **Correct** |
| `google_mlkit_face_detection` | processing, realtime (**2**) | ⚠️ only the `InputImage` factory | core (shared infra) + per-feature detectors | 🔴 **No shared home for the wrapper** |
| `google_mlkit_text_recognition` | processing, realtime (**2**) | ❌ none | core (shared infra) + per-feature detectors | 🔴 **No shared home** |
| `permission_handler` | capture (1) | ✅ `PermissionService` (core) | core or capture | ✅ Correct (core is fine) |
| `path_provider` | core-only | ✅ `FileService` | core | ✅ Correct |
| `image_picker` | (core gateway) | ✅ `ImagePickerGateway` | core | ✅ Correct |
| `hive_ce` | history (1) | ✅ `StorageService` init | history/data + core init | ✅ Correct |
| `pdf` | processing (1) | — (in processing) | processing/data | ✅ Correct (single feature) |
| MethodChannels ×4 (corner, pdf-raster, pdf-external) | various | ✅ all in `core/` | core | ✅ **Exemplary** |

**Verdict on the two questions:**
1. *"Is a bare native service in a feature correct?"* — A native wrapper in a feature is fine **only if exactly one feature uses that SDK** (e.g. `pdf` in processing). For an SDK used by **2+ features**, it should have a shared home in `core/`. Most of the app already does this (`camera`, channels, `path_provider`, `image_picker`). **ML Kit is the exception that proves the rule.**
2. *"Should these live in core, not a feature?"* — **Yes, for the shared ones.** `camera` and the platform channels are already correctly in `core/`. ML Kit face+text are the only native SDKs used by 2 features that **lack** a core home — that's the real inconsistency you spotted.

---

## 3. The ML Kit case — why it's NOT "just move to core and merge"

ML Kit face+text are used by **both** processing and realtime, so Rule B says "shared → core." But the two usages are **genuinely different** (measured):

| | processing (`content_detection_service`) | realtime (`face_detection` / `ocr_gate`) |
|---|---|---|
| Input | `InputImage.fromFilePath(path)` — a **file** | `CameraImage` — a **live frame** |
| Face mode | `FaceDetectorMode.accurate` | `FaceDetectorMode.fast` |
| Lifecycle | open/close detector per `detect()` call | detector kept open across frames |
| Returns | rich `DetectionResult` (domain) | lightweight `List<Face>` / `({bool hasText})` |
| Cadence | one-shot, quality-first | ~6–10 fps, speed-first |

These are the same *SDK* but different *use cases*. Merging them into one wrapper would be the **wrong abstraction** (Sandi Metz: *"duplication is far cheaper than the wrong abstraction"*) — you'd end up with mode flags and dual input paths in one class.

**So the correct model is the same one `camera` already uses:**
- **Shared, neutral infrastructure → `core/`** — the parts that are identical regardless of use case: the `CameraImage → InputImage` conversion (`realtime_input_image_factory`, `android_nv21`) is *already* in core. ✅ This is the genuinely shared piece.
- **Purpose-specific detectors → each feature's `data/`** — `content_detection_service` (accurate, path, one-shot) stays in processing/data; the realtime fast-frame detectors stay in realtime/data. They legitimately differ.

> **The key distinction:** `camera` shows the right pattern — `CameraSessionService` (the shared device/lifecycle infra) is in `core/`, but *how capture vs realtime drive it* lives in each feature. ML Kit should mirror this: shared conversion infra in core (already there), purpose-specific detectors per feature.

---

## 4. Decision

**Do:**
1. **Layer realtime's detectors into `realtime/data/`** (they're single-purpose realtime infra — fast-frame detection). This is the [REALTIME_NATIVE_BOUNDARY](./REALTIME_NATIVE_BOUNDARY.md) move; it puts the ML Kit wrappers in a proper `data/` folder instead of a flat `services/`.
2. **Leave processing's `content_detection_service` in `processing/data/`** (single-purpose: accurate path-based detection).
3. **Keep the shared ML Kit *infrastructure* (InputImage factory) in `core/`** — it already is. Optionally move `realtime_input_image_factory` from `core/utils/` to `core/platform/` to sit beside the other native adapters (cosmetic).

**Don't:**
- ❌ Merge processing + realtime ML Kit detectors into one core wrapper — different modes/inputs/lifecycles = the wrong abstraction.
- ❌ Per-frame map `CameraImage`/`Face` into DTOs (Fowler "Local DTO" is harmful; 16ms budget).

**Net:** the native strategy becomes uniform and rule-driven: *shared device/SDK infrastructure → `core/`; purpose-specific use of it → each feature's `data/`.* This is exactly how `camera` and the platform channels already work; applying it makes ML Kit consistent and answers both of your questions — a feature-local native service is correct **when it's that feature's specific use**, and the **shared** infrastructure belongs in `core/` (where camera and the channels already live).

---

## 5. One-paragraph answer

You spotted a real inconsistency: ML Kit face+text are used by two features but, unlike `camera` (whose shared `CameraSessionService` lives in `core/`), they had no shared core home — each feature wrapped the SDK independently. The fix is **not** to merge them, though: measured, processing uses ML Kit one-shot on a file in *accurate* mode returning a rich domain result, while realtime uses it per-frame on a live `CameraImage` in *fast* mode returning lightweight data — different use cases that share an SDK, not an implementation. The correct, rule-driven model (identical to how `camera` is already handled) is: **the shared, neutral conversion infrastructure lives in `core/` (it already does), and each feature keeps its purpose-specific detector in its own `data/` layer.** So a native service inside a feature *is* correct when it's that feature's specific use of the SDK; the shared infrastructure is what belongs in `core/`.
