# Folder Conventions — Which Sub-Folders Belong Under Each Layer

> The question: under a feature's `domain/`, `data/`, `presentation/` layers, **which sub-folders are legitimate** — are `enums/`, `coordinators/`, `state/`, `mappers/`, `actions/`, `datasources/` vs `services/` all correct? And in the **data layer specifically**, what's the right split?
>
> Answered against the accepted clean-architecture conventions (Reso Coder three-layer, Code With Andrea, official Flutter) + a per-folder audit of this repo.

**Date:** 2026-06-30 · Companion to [SERVICE_PLACEMENT.md](./SERVICE_PLACEMENT.md), [ENGINEERING_STANDARDS.md](./ENGINEERING_STANDARDS.md).

---

## 1. The rule for sub-folders: group by *kind of thing*, only when there's more than one

Two principles decide every sub-folder:

1. **A sub-folder names a *role* within its layer** (entities, use cases, repositories, widgets…). The role must be one the layer legitimately contains (see the canonical sets below).
2. **Don't create a sub-folder for a single file's sake prematurely** — but in a feature-first showcase, consistent role-folders aid navigation even at one file each. This repo's convention: **use the role-folder when the role exists in that feature**, omit it otherwise. (Code With Andrea: organize by feature, then by the layer's roles; Reso Coder: `data/{datasources,models,repositories}`, `domain/{entities,repositories,usecases}`, `presentation/{bloc,pages,widgets}`.)

---

## 2. Canonical sub-folders per layer (the accepted set)

### `domain/` — pure business, framework-free
| Sub-folder | Legit? | What it holds |
|---|---|---|
| `entities/` | ✅ canonical | Business objects (Reso Coder, CWA) |
| `usecases/` | ✅ canonical | One action each, `call()` |
| `repositories/` | ✅ canonical | **Abstract** repository contracts |
| `services/` | ✅ accepted | Abstract **domain-service** contracts (DDD domain services) — see [SERVICE_PLACEMENT](./SERVICE_PLACEMENT.md) |
| `value_objects/` / `failures/` | ✅ optional | Used if you have them (this repo keeps failures in `core/error`) |

### `data/` — implements domain contracts, touches IO/SDKs
| Sub-folder | Legit? | What it holds |
|---|---|---|
| `repositories/` | ✅ canonical | Repository **implementations** |
| `datasources/` | ✅ canonical | Raw IO / SDK wrappers (Reso Coder's term) — remote/local/device sources |
| `models/` (DTOs) | ✅ canonical | Serializable models that map to/from entities (Hive/JSON) |
| `services/` | ✅ accepted | The official-Flutter "Service" (plugin/API wrapper) — synonym/sibling of `datasources/` |

> **`datasources/` vs `services/` in `data/`:** they name the *same role* (wrap an external source) under two accepted vocabularies — Reso Coder says `datasources/`, official Flutter says "services". **Pick one per feature and be consistent.** Having *both* in one feature is only justified if you draw a real distinction (e.g. `datasources/` = thin SDK wrappers, `services/` = multi-source orchestration). See the realtime note in §3.

### `presentation/` — UI + state (Flutter/GetX)
| Sub-folder | Legit? | What it holds |
|---|---|---|
| `pages/` (or `views/`) | ✅ canonical | Full screens |
| `widgets/` | ✅ canonical | Feature-scoped widgets |
| `controllers/` (or `bloc/`/`viewmodels/`) | ✅ canonical | State holders (GetX controllers here) |
| `bindings/` | ✅ GetX-canonical | GetX DI wiring per route |
| `state/` | ✅ accepted | Reactive view-state holders (ViewModels that aren't the controller) |
| `coordinators/` | ✅ accepted | Presentation-tier orchestrators (lifecycle/stream) that hold Rx/GetX state |
| `models/` | ✅ accepted | Presentation-only models (UI config, view enums' companions) |
| `enums/` | ✅ accepted | Presentation-only enums |
| `mappers/` | ✅ accepted | Map domain → another feature's entity at the presentation edge |
| `actions/` | 🟡 borderline | A single "do X" command object; fine but rare — could be a controller method |

---

## 3. This repo — per-feature audit

| Feature | Layer | Sub-folders | Verdict |
|---|---|---|---|
| **processing** | domain | `entities, services, usecases` | ✅ All canonical. (`repositories/` correctly **removed** — its contract became a domain *service*.) |
| | data | `services` | ✅ Correct. Holds the 4 SDK/IO impls (`image_processing_service_impl`, `content_detection_service`, `document_crop_service`, `face_annotator_impl`). (`repositories/` correctly **removed**.) |
| | presentation | `bindings, controllers, mappers, pages, widgets` | ✅ All legit; `mappers/` is the accepted edge-mapper role. |
| **history** | domain | `entities, repositories, usecases` | ✅ Canonical (real repository → keeps `repositories/`). |
| | data | `models, repositories` | ✅ Canonical (DTO `models/` + repo impl). |
| | presentation | `bindings, controllers, pages, widgets` | ✅ Clean minimal set. |
| **realtime** | data | `datasources, services` | 🟡 **Both present** — justified *only if* the distinction holds: `datasources/` = thin ML-Kit wrappers (face, ocr), `services/` = orchestration/compute (pipeline, preview, normalizer, perf). That distinction *is* real here, so it's defensible — but document it (done below). |
| | presentation | `bindings, controllers, coordinators, enums, models, state, widgets` (+pages) | ✅ All accepted roles. The richest set, justified by realtime's complexity (live overlay state, frame coordinators, native-rotation enums). |
| **capture** | presentation | `actions, bindings, controllers, models, pages, widgets` | ✅ Legit; `actions/` (one command object) is borderline-but-fine. |
| **batch** | presentation | `bindings, controllers, models, pages, widgets` | ✅ Clean. |
| **result** | presentation | `bindings, controllers, pages, widgets` | ✅ Minimal, correct. |

**Cleanups done as part of this review:** removed the now-empty `processing/domain/repositories/` and `processing/data/repositories/` left behind by the Step A rename (a renamed-concept artifact — empty dirs read as "half-finished refactor").

---

## 4. The one judgment call: realtime's `data/{datasources, services}`

Per §2, having **both** `datasources/` and `services/` in one `data/` layer needs a real distinction. Here it holds:

- **`data/datasources/`** — thin wrappers over an external SDK, one per source: `realtime_face_detection_service` (ML-Kit FaceDetector), `realtime_ocr_gate_service` (ML-Kit TextRecognizer). They *only* wrap the SDK and return its output. This is exactly Reso Coder's "datasource = the boundary to a 3rd-party library."
- **`data/services/`** — compute/orchestration over those datasources: `realtime_detection_pipeline_coordinator` (runs OCR→face→edge, writes overlay), `realtime_preview_builder` (isolate image compositing), `realtime_face_geometry_normalizer` (Face→Rect/Offset translation), `realtime_frame_perf_tracker`.

So the split is **datasource (raw SDK) vs service (logic over sources)** — a legitimate, intentional distinction, not duplication. Processing doesn't need the split because its single `content_detection_service` is both wrapper and the only detection unit.

> **Convention recorded:** when a feature has both, `data/datasources/` = one-SDK-each thin wrappers; `data/services/` = compute/orchestration that consumes datasources. A feature with only thin wrappers uses just `datasources/`; one with only orchestration-over-one-source uses just `services/`.

---

## 5. One-paragraph answer

Under each layer, the legitimate sub-folders are **role-folders the layer actually contains**: `domain/` → `entities`, `usecases`, `repositories` (abstract), and `services` (abstract domain-service contracts); `data/` → `repositories` (impl), `datasources`/`services` (SDK/IO wrappers), and `models` (DTOs); `presentation/` → `pages`, `widgets`, `controllers`, `bindings`, plus accepted extras `state`, `coordinators`, `models`, `enums`, `mappers`, and the borderline `actions`. **Every sub-folder in this repo maps to one of those accepted roles** — so yes, `enums/`, `coordinators/`, `state/`, `mappers/` are all correct (presentation-tier roles). The only nuance is realtime's `data/{datasources, services}`: having both is right *only because* there's a genuine datasource-vs-orchestration distinction, which there is. Two empty `repositories/` folders left over from the processing rename were removed as part of this review.
