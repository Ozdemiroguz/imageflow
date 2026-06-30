# Where Do "Services" Belong? — A Sourced Guide (and ImageFlow's audit)

> The word **"service"** is overloaded — it means at least four different things, and each belongs in a *different* layer. This doc explains the rule, cites authoritative sources, and then audits **where every service in ImageFlow actually sits** — marking what's correct and what's inconsistent.
>
> Written because the codebase currently has "services" in **four** locations, and that looked arbitrary. It mostly isn't — but one location (`features/<f>/services/`) is genuinely inconsistent, and this doc says exactly why and what to do.

**Date:** 2026-06-30 · Companion to [ENGINEERING_STANDARDS.md](./ENGINEERING_STANDARDS.md), [LAYERING_REVIEW.md](./LAYERING_REVIEW.md), [FOLDER_CONVENTIONS.md](./FOLDER_CONVENTIONS.md), [REALTIME_NATIVE_BOUNDARY.md](./REALTIME_NATIVE_BOUNDARY.md).

> **Update — RESOLVED:** the flat-`services/` inconsistency flagged below has been **fully fixed across all features.** No feature has a bare `services/` folder anymore — every service now sits in a proper layer by the import litmus (§1):
> - **realtime** → `data/datasources/` (ML-Kit wrappers), `data/services/` (detection/preview/compute), `presentation/coordinators/` (GetX session/stream).
> - **capture** → `presentation/coordinators/` (the camera-lifecycle helper).
> - **batch** → `presentation/coordinators/` (state manager, queue fn, metrics — all operate on presentation models).
>
> Only `core/services`, `core/platform`, `core/presentation`, and each feature's `domain/services` (abstract) + `data/services` (impl) remain — all canonical. The §4 table below is the **original** audit snapshot kept for the reasoning trail.

---

## 1. The one rule that decides everything: **classify by imports**

From Uncle Bob's **Dependency Rule** — *"source code dependencies can only point inwards… the name of something declared in an outer circle must not be mentioned by the code in an inner circle"* ([The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)). Frameworks/SDKs/the database are **outermost details** — "we keep these things on the outside where they can do little harm."

So for **any** class called a "service", look at its `import` lines and apply this decision procedure:

| What it imports / does | What it IS | Where it goes |
|---|---|---|
| `package:camera`, `google_mlkit_*`, `hive`, `path_provider`, `dart:io`, `MethodChannel`, `http`/`dio`, Firebase | **Infrastructure service** (data source / SDK wrapper) | `data/` (one feature) **or** `core/services/` (≥2 features) |
| Only Dart + your own domain models; business logic not fitting one entity; stateless | **Domain Service** | `domain/services/` as an **abstract interface** (impl in `data/` via Separated Interface) |
| Multiple repositories, no Flutter, no SDK; stateless use-case coordinator | **Application service** | feature `application/` (or a `domain/usecases` interactor) |
| `flutter/material.dart`, widgets, `BuildContext`, lifecycle | **Presentation** (not a "service" at all) | `presentation/` |

> **The litmus is mechanical and grep-able**: a class importing a framework/SDK *cannot* be in `domain/`; a framework-free business-rule class *can*. Everything below follows from this.

---

## 2. The four meanings of "service" (with sources)

### (A) DDD **Domain Service** — business logic, in the domain layer
*"When a significant process or transformation in the domain is not a natural responsibility of an ENTITY or VALUE OBJECT, an operation should be added… as a standalone interface declared as a SERVICE."* — Eric Evans, *Domain-Driven Design* (via [Martin Fowler](https://martinfowler.com/bliki/EvansClassification.html)). Evans' three-part test: the operation (1) relates to a domain concept not natural to an entity/VO, (2) is defined in terms of the domain model, (3) is **stateless**.

The interface may live in `domain/` even if its implementation needs infrastructure — that's the **Separated Interface** pattern (Vaughn Vernon, *Implementing DDD*, Ch. 7 "Is Separated Interface a Necessity?"). Same mechanism Microsoft documents for repositories: *"the domain model layer includes the repository contracts (interfaces)… the implementation… must be placed outside… in the infrastructure layer… so the domain model layer isn't 'contaminated'"* ([Microsoft DDD](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model)).

> ⚠️ Guardrail: don't push *all* logic into domain services or you get an **anemic domain model** (Microsoft). Entities should carry behavior; a domain service is for logic that genuinely spans entities.

### (B) Official Flutter **"Service"** — an SDK/plugin wrapper, in the data layer
The official [Flutter App Architecture guide](https://docs.flutter.dev/app-architecture/guide) is unusually precise: *"**Services are in the lowest layer… They wrap API endpoints… They're only used to isolate data-loading, and they hold no state.** Your app should have **one service class per data source.** Examples… The underlying platform, like **iOS and Android APIs**; REST endpoints; Local files."* And: *"a service… **wraps an external API**… generally one per data source, such as a… **platform plugin**… It's important that the service is a **private member**, so the UI can't bypass the repository."* ([data-layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer)).

→ **camera / ML Kit / files / platform channels are textbook official-Flutter "Services" and belong in the data layer (or `core/` if shared).**

### (C) **Application service** — a thin use-case coordinator
*"Application: services… consider writing a service class [only] if [logic] depends on multiple data sources or repositories AND needs to be shared by more than one widget."* with the caveat *"service classes are often unnecessary… no point if all it does is forward calls from a controller to a repository… the application layer is optional"* (Code With Andrea, [Application Layer](https://codewithandrea.com/articles/flutter-app-architecture-application-layer/)). Matches Evans' Application Layer: *"kept thin… coordinates tasks and delegates… can have state that reflects the progress of a task."*

### (D) **Cross-feature infrastructure** — in `core/`
*"These folders contain code that is **truly shared** across features… relatively little code"* (Code With Andrea, [Project Structure](https://codewithandrea.com/articles/flutter-project-structure/)). Reso Coder pulls *"anything which has to be shared between multiple features into the core folder"* — and his `core/network/NetworkInfo` (a connectivity-plugin wrapper) is the proof-by-example that a **cross-feature SDK wrapper lives in `core/`**, not in one feature ([Reso Coder](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)).

**`core/` vs one feature → count the consumers:** used by ≥2 features → `core/`; used by exactly one → keep it inside that feature.

---

## 3. ImageFlow's four locations — the audit

| Location | Verdict | Why (sourced) |
|---|---|---|
| `features/processing/domain/services/` — `ContentDetector`, `DocumentCropper`, `ImageProcessingService` (interfaces) | ✅ **Correct** | Abstract, **framework-free** (verified: import only `core/`, entities). Domain-service interfaces via Separated Interface (Evans/Vernon). |
| `features/processing/data/services/` — `ContentDetectionService`, `DocumentCropService`, `ImageProcessingServiceImpl` | ✅ **Correct** | They import `google_mlkit_*` / `image` / `pdf` → infrastructure. This **is** the official-Flutter data-layer "Service" (B). |
| `core/services/` + `core/platform/` — `FileService`, `PermissionService`, `CameraSessionService`, `NativeCornerDetectionService`, `PdfRasterService`, `ImagePickerGateway`, … | ✅ **Correct** | Each wraps one plugin/channel (`path_provider`, `permission_handler`, `camera`, `MethodChannel`) and is shared by ≥2 features → cross-feature infrastructure (D). Mirrors Reso Coder's `core/network`. |
| `features/{realtime,capture,batch}/services/` — bare `services/`, not under `data/` or `application/` | ⚠️ **Inconsistent** | **No PRIMARY source defines a bare `features/<f>/services/` folder.** The community disagrees here. Must be reclassified by imports (§1). |

### Why the bare `services/` folder is the inconsistency

`processing` is layered correctly (`domain/services` interfaces + `data/services` impls). But `realtime`, `capture`, and `batch` dump everything into a flat `services/` — and a grep of their imports shows it's actually **three different kinds of class mixed together**:

| File (sample) | Imports | What it really is | Should live in |
|---|---|---|---|
| `realtime/services/realtime_face_detection_service.dart` | `google_mlkit_face_detection`, `camera` | **Infra** (SDK wrapper) | `realtime/data/` (or `core/` — it's ML Kit, like processing's detector) |
| `realtime/services/realtime_ocr_gate_service.dart` | `google_mlkit_text_recognition`, `camera` | **Infra** | `realtime/data/` |
| `realtime/services/realtime_preview_builder.dart` | `camera`, `image` | **Infra** (image pipeline) | `realtime/data/` |
| `realtime/services/realtime_*_coordinator.dart`, `realtime_frame_processor.dart` | `camera`, `get` | **Presentation coordinators** (orchestrate + GetX) | `realtime/presentation/` |
| `realtime/services/realtime_face_geometry_normalizer.dart`, `realtime_frame_perf_tracker.dart` | pure Dart (+ ML Kit *types*) | pure helpers | `realtime/data/` or a util |
| `capture/services/camera_capture_*_helper.dart` | `camera`, `get` | **Presentation helpers** | `capture/presentation/` |
| `batch/services/batch_queue_initializer.dart`, `batch_run_metrics_tracker.dart`, `batch_history_mapper.dart` | pure Dart (+ `get`) | **Application coordinators** | `batch/application/` |

So the bare `services/` folder is a **catch-all that hides the layer of each class.** Processing already shows the right pattern; realtime/capture/batch just never applied it.

---

## 4. Honest verdict & recommendation

**What's genuinely correct (keep):** the `domain/services` ↔ `data/services` split in processing, and everything in `core/services` + `core/platform`. These are textbook and fully defensible to a senior reviewer.

**What's inconsistent (the bare `features/<f>/services/`):** not wrong *behaviorally*, and not even wrong by the import litmus *for the infra ones* (an SDK wrapper in a feature is fine — it's just mis-foldered). But it's **inconsistent with how `processing` is layered in the same codebase**, and that asymmetry is exactly what a sharp reviewer flags: *"why is processing layered and realtime not?"*

**Two honest options:**

1. **Full consistency (more work):** reclassify each bare-`services/` file by its imports into `data/` (SDK wrappers), `presentation/` (GetX coordinators/lifecycle helpers), or `application/` (batch's pure coordinators) — matching processing. Highest senior-defensibility; touches imports across realtime/capture/batch.
2. **Documented convention (cheap):** keep `features/<f>/services/` but **define it explicitly** in ENGINEERING_STANDARDS as "this project's name for a feature's infrastructure + coordinator helpers," and note it's a deliberate simplification over the canonical `data/`/`application/`/`presentation/` split. Defensible *if stated*, because the real sin is *silent* inconsistency, not the folder itself.

> **Recommendation:** option 1 for `realtime` at minimum (it's the largest, most-scrutinized feature and its SDK wrappers clearly mirror processing's `data/services`), and option 2's explicit note for the rest. The decisive principle to cite in review either way: **a "service" is classified by what it imports** — infra → `data`/`core`, business logic → `domain`, coordination → `application`, widgets → `presentation`.

---

## 5. One-paragraph answer to "is this right?"

`domain/services/` (interfaces) and `data/services/` (impls) in **processing** are correct and textbook — domain holds the framework-free contract, data holds the SDK-touching implementation, exactly per Evans/Vernon + the official Flutter "Service" definition. `core/services/` is the correct home for plugin wrappers shared across features (Reso Coder's `core/network` pattern). The **only** real issue is the bare `features/{realtime,capture,batch}/services/` folder: no authoritative source defines it, and inside it sit infra wrappers, presentation coordinators, and application helpers all mixed together — the same classes that `processing` correctly separates into `data/` and `domain/`. Fixing it means moving each by its imports; the litmus is mechanical.

---

## Sources
- Uncle Bob — [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- Eric Evans, *Domain-Driven Design* — Service definition via [Martin Fowler: Evans Classification](https://martinfowler.com/bliki/EvansClassification.html)
- Vaughn Vernon, *Implementing Domain-Driven Design*, Ch. 7 "Services"
- Microsoft — [Tactical DDD](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-domain-driven-design) · [DDD-oriented microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/ddd-oriented-microservice) · [domain model layer](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model)
- Official Flutter — [App Architecture guide](https://docs.flutter.dev/app-architecture/guide) · [Data layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer)
- Code With Andrea — [Project Structure](https://codewithandrea.com/articles/flutter-project-structure/) · [Application Layer](https://codewithandrea.com/articles/flutter-app-architecture-application-layer/) · [Presentation Layer](https://codewithandrea.com/articles/flutter-presentation-layer/)
- Reso Coder — [TDD Clean Architecture [1]](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)
