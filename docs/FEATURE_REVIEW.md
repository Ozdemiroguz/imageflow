# ImageFlow — Feature-Level Review

> A feature-by-feature assessment: is any feature **redundant**, **bloated**, **mislayered**, or **missing**? Evidence-based — every claim is backed by the route table, the cross-feature import matrix, and measured sizes.
>
> Conclusion up front: **no feature is redundant and none is missing — the flow is complete and the layering is consistent.** Two minor observations are noted and judged defensible.

**Date:** 2026-06-30 · Companion to [LAYERING_REVIEW.md](./LAYERING_REVIEW.md), [SERVICE_PLACEMENT.md](./SERVICE_PLACEMENT.md).

---

## 1. The feature map (what's reachable, and how the flow connects)

Every feature is bound to a real route ([app_pages.dart](../imageflow/lib/core/routes/app_pages.dart)); none is dead code.

```
 home = HistoryPage ──FAB──▶ capture ─┐
                       │     realtime ─┼─▶ processing ──▶ result
                       │     batch ────┘   (batch runs ProcessImage in a loop)
                       └──▶ historyDetail
```

The app is a complete **create → process → show → persist** loop:
- **create** (acquire an image): `capture`, `realtime`, `batch`
- **process** (the pipeline): `processing`
- **show** (the outcome): `result`
- **persist + browse**: `history` (+ `historyDetail`)

There is no gap in this loop (nothing is acquired-but-never-processed, or produced-but-never-shown), and no feature sits outside it. **No missing feature; no orphan feature.**

---

## 2. Per-feature verdict

| Feature | Files / LOC | Layers | Verdict | Evidence |
|---|---|---|---|---|
| **processing** | 21 / 1672 | domain, data, presentation, di | ✅ **Core, correctly full-layered** | The only feature with real business logic + a pipeline. Has entities, domain-service interfaces, data impls, use case. Consumed by `batch`, `result`. |
| **history** | 23 / 1198 | domain, data, presentation, di | ✅ **Correctly full-layered** | The home screen + persistence. A real repository (Hive), entity, Model↔Entity mapping, use cases. |
| **result** | 6 / 322 | presentation | ✅ **Correct (presentation-only)** | Smallest feature, but legitimate: it renders a `ProcessingResult`/`ProcessingHistory` passed via route args. **No domain/data is correct** — it owns no entities and persists nothing. |
| **batch** | 19 / 1441 | presentation, services | ✅ **Correct (no own domain)** | Orchestrates `ProcessImage` over a list (+ retry/stop/metrics). Reuses processing's domain rather than duplicating it — a `ProcessBatch` use case would wrap a `for` loop with no new business rule. Correct omission. |
| **capture** | 16 / 1277 | presentation, services | ✅ **Correct (device-IO)** | Picks an image / opens the camera, routes to `processing`. No business entities → no domain/data. Holds two responsibilities (see §4). |
| **realtime** | 28 / 4104 | presentation, services | ✅ **Correct, but the heaviest** | Live ML overlay (face + corner detection per frame). Largest feature by far (3× capture) — justified by genuine real-time multi-SDK complexity, not bloat (see §3). |

**No feature is redundant.** The closest candidates (`capture` vs `realtime`, and `result`'s small size) are addressed below and judged correct.

---

## 3. "Is `realtime` bloated?" — No (it's complexity, not bloat)

`realtime` is 4104 LOC — 3× `capture` and the biggest feature. That *looks* like a smell, so it was checked directly:

- Its weight is **real-time, multi-SDK vision**: per-frame face detection + native corner detection + OCR gating + geometry normalization + isolate-offloaded preview compositing. The biggest files are `realtime_preview_builder.dart` (537, isolate image pipeline) and `realtime_camera_controller.dart` (363, orchestration) — both doing genuinely hard work.
- The [LAYERING_REVIEW](./LAYERING_REVIEW.md) already judged the realtime *decomposition* as sound SRP (each coordinator splits along an independent change-reason/lifecycle), with exactly **one** real merge candidate (`RealtimeFrameProcessor` → `RealtimeDetectionPipelineCoordinator`).

**Verdict:** `realtime`'s size reflects inherent domain complexity, not redundant code. It is the one feature that would most benefit from a thin `domain/` contract (it does enough detection orchestration), but its output is ephemeral overlay (never persisted), so presentation-only is defensible.

---

## 4. "Is `capture` vs `realtime` redundant?" — No (different purpose, shared infra)

Both use the camera and share `CameraSessionService` ([core/services](../imageflow/lib/core/services/camera_session_service.dart)). But they are **not** duplicates:

| | `capture` | `realtime` |
|---|---|---|
| Purpose | Take a **static photo**, then process | **Live ML overlay** (detection drawn on the camera feed in real time) |
| Output | one image → `processing` | guidance overlay; capture → `processing` |
| Complexity | simple shutter | per-frame ML pipeline |

The shared camera-lifecycle code was already de-duplicated (the route-lifecycle coordinator merge). What remains distinct is genuinely distinct. **Not redundant.**

**Minor note (within `capture`):** the feature holds two responsibilities — `CaptureController` is a *source-picker dialog* (camera vs gallery, an entry-point/router) while `CameraCaptureController` is the *camera screen* itself. A reviewer could ask "why are both in `capture`?" It's defensible (both are about acquiring an image), but splitting the source-picker out as an entry-point concern would sharpen the boundary. **MINOR — not acted on.**

---

## 5. Cross-feature coupling — is the dependency direction clean?

Measured the relative imports that reach from one feature into another, and checked **which layer** they land in (domain-only = good; presentation/data = coupling):

| Coupling | Lands in | Verdict |
|---|---|---|
| `batch → processing` | `domain/` ×6, `di/` ×1, `presentation/` ×1 (the shared mapper) | ✅ Good — reuses the processing **domain** (`ProcessImage`, entities). The one `presentation/` import is `ProcessingHistoryMapper`. |
| `result → processing` / `result → history` | `domain/` only | ✅ Clean — consumes domain entities only. |
| `processing → history` | `domain/` ×3, `di/` ×1 | ✅ Clean — uses `SaveHistory` (domain). |
| `history → capture` | `presentation/bindings → presentation/actions` (`OpenCaptureDialogAction`) | 🟡 Minor — the home screen depends on a sub-feature's presentation action (the FAB opens the capture dialog). Presentation-to-presentation, so not a layer violation, but it's the one "upward-ish" coupling. |

**Overall: coupling is domain-directed and clean.** Features depend on each other's **domain**, not their internals — exactly what feature-first + the Dependency Rule want. The only cross-presentation edges are the FAB→capture-dialog action and the shared `ProcessingHistoryMapper`; both are benign, though the mapper (now used by `processing` *and* `batch`) is a candidate to promote to `core/` if a third consumer appears.

---

## 6. Layer completeness — consistent rule, consistently applied

| Feature | domain | data | Why |
|---|---|---|---|
| processing | ✅ | ✅ | Real entities + pipeline + persistence boundary |
| history | ✅ | ✅ | Real entity + Hive persistence |
| result | — | — | Renders passed-in data; owns nothing |
| batch | — | — | Orchestrates existing domain over a list |
| capture | — | — | Device-IO, no business entity |
| realtime | — | — | Ephemeral overlay, no persisted entity |

The rule is crisp and **uniformly applied**: a feature gets `domain/data` **iff it owns a business entity / persistence boundary.** Exactly the two data-owning features have them; the four orchestration/UI features correctly omit them. This is the right call (the official Flutter guide: the domain layer is optional, add it only when warranted).

---

## 7. Bottom line

- **Redundant feature?** None. `capture`/`realtime` overlap in tooling but not in purpose; `result` is small but legitimate.
- **Bloated feature?** None structurally. `realtime` is large because its domain (real-time multi-SDK vision) is large — and its decomposition is sound (one merge pending, tracked in LAYERING_REVIEW).
- **Missing feature?** None. The create→process→show→persist loop is complete.
- **Mislayered?** No feature is in the wrong place; the two minor couplings (FAB→capture action; shared mapper) are presentation-level and benign.

For a portfolio reviewer, the feature architecture reads as **deliberate and complete**: a clean vertical slice per user task, domain-directed coupling, and a consistent "full layers only where there's an entity" rule. The only things to *mention* (not fix) are `capture`'s two-responsibilities and `realtime`'s size — both defensible with the reasoning above.
