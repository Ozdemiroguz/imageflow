# ImageFlow — Engineering Standards

> A reference specification for **Flutter (stable, Dart 3.x)** projects built on **Clean Architecture**, **Clean Code**, and **GetX** for state management, dependency injection, and routing.
>
> This document is the **source of truth** the codebase is audited against. Every rule is intended to be *checkable* (lint, test, or review) and is backed by an authoritative source. Where the community genuinely disagrees, the disagreement is stated and a project decision is recorded rather than hidden.

**Status:** Baseline standard · **Audience:** A technical evaluator reviewing this repository as a portfolio/showcase · **Stack:** Flutter stable · Dart 3.x · GetX · Hive CE · ML Kit

---

## Table of Contents

1. [How to Read This Document](#1-how-to-read-this-document)
2. [Architecture: Clean Architecture](#2-architecture-clean-architecture)
3. [The Dependency Rule & Layer Contracts](#3-the-dependency-rule--layer-contracts)
4. [SOLID Principles (Operationalized)](#4-solid-principles-operationalized)
5. [Project & Folder Structure](#5-project--folder-structure)
6. [Error Handling: Result / Failure](#6-error-handling-result--failure)
7. [GetX Integration Rules](#7-getx-integration-rules)
8. [State Management & Controllers](#8-state-management--controllers)
9. [Dependency Injection (Bindings)](#9-dependency-injection-bindings)
10. [Clean Code Rules (Dart)](#10-clean-code-rules-dart)
11. [Dart 3.x Idioms](#11-dart-3x-idioms)
12. [Effective Dart: Style, Usage, Design, Docs](#12-effective-dart-style-usage-design-docs)
13. [Lint Policy](#13-lint-policy)
14. [Widget & Build Discipline](#14-widget--build-discipline)
15. [Performance](#15-performance)
16. [Testing & Testability](#16-testing--testability)
17. [Definition of Done (Audit Checklist)](#17-definition-of-done-audit-checklist)
18. [Sources](#18-sources)

---

## 1. How to Read This Document

This document uses the **Effective Dart** convention for the strength of each rule ([dart.dev/effective-dart](https://dart.dev/effective-dart)):

- **DO** — a practice that should always be followed.
- **DON'T** — a practice that should never be done.
- **PREFER** — a practice that should be followed in the vast majority of cases.
- **AVOID** — a practice that should rarely be done.
- **CONSIDER** — a practice you might or might not follow depending on circumstances.

Each rule cluster is tagged with how it is enforced:

- 🟢 **[lint]** — machine-enforced by `analysis_options.yaml`. Non-negotiable; CI fails.
- 🔵 **[test]** — verified by the test suite.
- 🟡 **[review]** — verified by human code review against this doc.

A rule that is **[lint]** must never be waived silently with `// ignore:` without a one-line justification comment.

---

## 2. Architecture: Clean Architecture

We follow Robert C. Martin's **Clean Architecture** ([blog.cleancoder.com, 2012](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)), applied to Flutter via the widely-cited **feature-first three-layer** convention popularized by Reso Coder and Code With Andrea, and corroborated by the official [Flutter App Architecture guide](https://docs.flutter.dev/app-architecture/guide).

### 2.1 The three layers (per feature)

```
features/<feature>/
├── domain/         ← innermost. Pure Dart. Knows nothing about Flutter, GetX, Hive, or ML Kit.
│   ├── entities/        business objects (immutable)
│   ├── repositories/    ABSTRACT contracts only (interfaces)
│   └── usecases/        one action each, callable via call()
├── data/           ← implements domain contracts. Knows about frameworks/IO.
│   ├── models/          DTOs (serializable; Hive/JSON), map to/from entities
│   ├── datasources/     raw IO (DB, files, ML Kit, native channels)  [where applicable]
│   └── repositories/    repository IMPLEMENTATIONS
└── presentation/   ← UI + state. Knows about Flutter and GetX. Depends on domain only.
    ├── controllers/     GetxControllers (presentation state holders)
    ├── bindings/        GetX DI wiring for this feature
    ├── pages/           full screens
    └── widgets/         feature-scoped widgets
```

Cross-cutting code that is not owned by a single feature lives under `lib/core/` (theme, error types, shared services, routing, design-system widgets). This is the standard "escape hatch" both camps agree on ([Code With Andrea — Project Structure](https://codewithandrea.com/articles/flutter-project-structure/)).

### 2.2 Recorded project decisions (where the community disagrees)

| Topic | Community split | **Our decision** |
|---|---|---|
| Is the **domain layer** mandatory? | Official Flutter docs call it *optional*; Reso Coder/Uncle Bob make it the core. | **Mandatory.** As a showcase of Clean Architecture, every feature with business logic has `domain/`. Trivial UI-only features may omit `usecases/`. |
| Are **use cases** required, or can controllers call repositories? | VGV's 4-layer model lets Blocs call repositories directly; Reso Coder mandates use cases. Official Flutter docs call a *pass-through* use case ceremony. | **Required for business operations — uniformly, even single-caller pass-throughs** (e.g. `GetAllHistory`, `DeleteHistory`). A use case = one action; controllers never call repositories directly. We accept the extra indirection deliberately: a *uniform* use-case layer is part of what this repo demonstrates, and it keeps every feature's controllers identical in shape. (`ProcessImage`/`SaveHistory` are additionally justified by multi-feature fan-out.) |
| **Entity vs Model** separation | Some apps reuse one class. | **Separated.** `domain` has entities; `data` has models (Hive/JSON). Models map to entities. Never the reverse. |
| **Feature-first vs layer-first** | Both exist. | **Feature-first**, per [Code With Andrea](https://codewithandrea.com/articles/flutter-project-structure/) — deleting a feature = deleting one folder. |

> **A "feature" is a functional requirement — what the user does (capture, process, batch, view history) — not a screen.** ([Code With Andrea](https://codewithandrea.com/articles/flutter-project-structure/))

---

## 3. The Dependency Rule & Layer Contracts

**The Dependency Rule (canonical):** *"Source code dependencies can only point inwards. Nothing in an inner circle can know anything at all about something in an outer circle."* — [Uncle Bob, The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

```
presentation  ───▶  domain  ◀───  data
   (outer)         (inner)        (outer)
```

- **DO** keep `domain/` pure Dart. 🟡 [review] / 🟢 [lint-able]
  - **DON'T** import `package:flutter/*`, `package:get/*`, `package:hive*`, ML Kit, or any IO package inside `domain/`. The domain should survive "porting to another framework" ([Reso Coder](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)).
- **DO** define repository **interfaces in `domain/repositories/`** and **implementations in `data/repositories/`**. Dependencies are inverted via DI (DIP). 🟡 [review]
- **DON'T** let `presentation/` import anything from `data/` directly. The presentation layer depends on `domain/` abstractions and receives concrete implementations through DI. 🟡 [review]
- **DON'T** let a domain entity reference a data model. The one-way dependency is **Model → Entity**, never Entity → Model. 🟡 [review]
- **DO** map DTOs to entities **inside the repository implementation** ([Code With Andrea — Repository Pattern](https://codewithandrea.com/articles/flutter-repository-pattern/)). 🟡 [review]

> **Audit-grep:** `domain/` files must not contain `import 'package:flutter`, `import 'package:get`, or `import 'package:hive`. A single hit is a finding.

---

## 4. SOLID Principles (Operationalized)

From R.C. Martin's [Principles of OOD](http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod). Each is rephrased as a checkable rule for this codebase.

- **S — Single Responsibility.** A class has one reason to change.
  - **AVOID** "god" classes. A repository implementation that *also* renders PDFs, runs isolates, and rewrites EXIF is doing several jobs — extract collaborators (services) it depends on. 🟡 [review]
  - Heuristic: a class >~250 lines or a method >~40 lines is a review flag, not an automatic failure.
- **O — Open/Closed.** Open for extension, closed for modification ([Uncle Bob](https://blog.cleancoder.com/uncle-bob/2013/03/08/AnOpenAndClosedCase.html)).
  - **PREFER** adding a new `sealed` subtype / new use case over editing a `switch` in many places. Exhaustive `switch` over a sealed type makes the extension points explicit.
- **L — Liskov Substitution.** An `ImageProcessingServiceImpl` must honor the full contract of `ImageProcessingService` — same error semantics, no surprise exceptions. 🔵 [test]
- **I — Interface Segregation.** Keep repository interfaces focused. Don't force a consumer to depend on methods it never calls; split fat interfaces. 🟡 [review]
- **D — Dependency Inversion.** *High-level modules depend on abstractions, not on low-level modules* ([DIP](https://en.wikipedia.org/wiki/Dependency_inversion_principle)).
  - **DO** inject dependencies through constructors as **abstract types**; register the concrete type once in a Binding. 🟡 [review]
  - **DON'T** call `Get.find<ConcreteImpl>()` from inside a controller or use case — depend on the abstraction passed to the constructor. 🟡 [review]

---

## 5. Project & Folder Structure

- **DO** use **feature-first** layout: `lib/features/<feature>/{domain,data,presentation}/`. 🟡 [review]
- **DO** keep cross-cutting concerns in `lib/core/`. 🟡 [review]
- **DO** name files, directories, and libraries in `lowercase_with_underscores` (snake_case). 🟢 [lint: `file_names`] ([Effective Dart: Style](https://dart.dev/effective-dart/style))
- **DO** make a file name mirror its primary type: `processing_controller.dart` → `ProcessingController`. 🟡 [review]
- **PREFER** one public class per file. Split helpers into sibling files (`*_typedef.dart`, `*_state.dart`) rather than growing one file. 🟡 [review]
- **DO** mirror `lib/` under `test/` exactly ([Flutter cookbook](https://docs.flutter.dev/cookbook/testing/unit/introduction)). 🔵 [test]

### 5.1 "Service" placement — classify by imports

The word **"service"** is overloaded; a class's **imports** decide its layer (the Dependency Rule). See [SERVICE_PLACEMENT.md](./SERVICE_PLACEMENT.md) for the full sourced rationale. The rule:

| The class imports / does | It is | It goes in |
|---|---|---|
| an SDK/plugin/IO (`camera`, `google_mlkit_*`, `hive`, `path_provider`, `dart:io`, `MethodChannel`) | infrastructure service (data source) | `data/services/` (one feature) or `core/services/` (≥2 features) |
| only Dart + domain models; framework-free business logic | **domain service** (interface) | `domain/services/` (impl in `data/` via Separated Interface) |
| `flutter`/widgets/`BuildContext`/GetX, manages UI lifecycle | presentation coordinator | `presentation/` |
| multiple repositories, no Flutter/SDK, stateless coordinator | application service | a feature `application/` or a `domain/usecases` interactor |

- **DON'T** place an SDK-wrapping service in `domain/` — `domain/services/` is for **framework-free interfaces only** (grep-checkable: no `package:flutter|get|hive|google_mlkit|camera|image|pdf` import). 🟡 [review] / 🟢 [grep]
- **Recorded project convention (deliberate deviation):** the older features `realtime`, `capture`, and `batch` keep a flat **`features/<f>/services/`** folder that mixes SDK wrappers, GetX coordinators, and pure helpers. No authoritative source defines a bare feature-level `services/` folder; the canonical layering (as done in `processing`: `domain/services` + `data/services`) is preferred. This flat folder is an **accepted legacy simplification, documented rather than silent** — new features and any refactor of these three SHOULD follow the import-classification table above instead. 🟡 [review]

---

## 6. Error Handling: Result / Failure

We use a **sealed `Result<T>`** with an `Ok`/`Error` pair and a sealed **`Failure`** hierarchy — the non-functional equivalent of `Either<Failure, T>`, endorsed by the official [Flutter "Result objects" pattern](https://docs.flutter.dev/app-architecture/design-patterns/result) and [Code With Andrea](https://codewithandrea.com/articles/functional-error-handling-either-fpdart/).

**Why:** *Result classes force the caller to check for errors at compile time; exceptions hide failure at runtime.*

- **DO** return `Future<Result<T>>` (or `Result<T>`) from every repository and use case method. 🟡 [review]
- **DON'T** let exceptions cross a layer boundary into `presentation/`. Catch at the `data` boundary and convert to a `Failure`. 🟡 [review]
- **DO** model failures as a **sealed** `Failure` hierarchy so the presentation layer can `switch` exhaustively (e.g., `DetectionFailure`, `PermissionFailure`, `StorageFailure`). 🟡 [review]
- **DO** unwrap results with a `switch` on the sealed type (`case Ok(:final value)` / `case Error(:final failure)`) rather than `isOk` boolean checks where exhaustiveness matters. 🟡 [review]
- **AVOID** bare `catch` without an `on` clause; **DON'T** silently swallow errors. 🟢 [lint: `avoid_catches_without_on_clauses` (opt-in)] ([Effective Dart: Usage](https://dart.dev/effective-dart/usage), [linter rule](https://dart.dev/tools/linter-rules/avoid_catches_without_on_clauses))
  - When a generic `catch (e, st)` is used at an IO boundary (e.g. a `guard` helper), it **must** log and convert to a typed `Failure` — never discard.
- **DON'T** return `null` to signal failure, and **DON'T** pass `null` to signal "no value" where a typed result or special-case object fits ([Clean Code](https://gist.github.com/wojteklu/73c6914cc446146b8b533c0988cf8d29)).
- **DO** use `rethrow` (not `throw e`) when re-raising. 🟢 [lint: `use_rethrow_when_possible`]

---

## 7. GetX Integration Rules

GetX provides three pillars: **state management**, **dependency injection**, and **routing** ([pub.dev/packages/get](https://pub.dev/packages/get)). It is fast and low-boilerplate but **does not enforce structure** — so this section exists to impose the discipline GetX omits.

> **Honest trade-off (for the evaluator).** GetX is criticized for: (a) a global service-locator (`Get.find()`) that hides dependencies; (b) navigation/snackbars/dialogs that use a global context, which complicates unit testing; (c) bundling many concerns; and (d) global state leaking across tests ([critique 1](https://medium.com/@darwinmorocho/flutter-should-i-use-getx-832e0f3a00e8), [critique 2](https://medium.com/@mdriazofficial/building-scalable-flutter-apps-with-getx-lessons-pitfalls-and-fixes-f426c8eda11a)). We accept GetX for its productivity **and explicitly mitigate each criticism** with the rules below.

**Mitigations (mandatory):**

- **DO** inject every dependency through the **constructor** of a controller/use case. `Get.find()` is allowed **only inside Bindings** (the composition root), never inside controllers, use cases, repositories, or widgets. 🟡 [review]
  - *This neutralizes the "service-locator hides dependencies" criticism — every class's dependencies are visible in its constructor and mockable in tests.*
- **DON'T** put business logic, API calls, or IO inside controllers or widgets — they belong in use cases / repositories ([Clean Arch + GetX](https://blog.adityasharma.co/building-flutter-apps-with-clean-architecture-using-getx)). 🟡 [review]
- **DO** register dependencies in exactly **one place per feature** (a Binding). 🟡 [review]
- **DO** call `Get.reset()` (or `Get.testMode`) between tests to prevent global-state contamination. 🔵 [test]
- **AVOID** global/permanent controllers. Scope controllers to routes via Bindings so GetX disposes them when the route is popped. Use `GetxService` only for genuine app-lifetime singletons. 🟡 [review]
- **CONSIDER** wrapping GetX navigation behind a `NavigationService`/route abstraction so presentation logic can be tested without the global navigator. 🟡 [review]

---

## 8. State Management & Controllers

- **DO** keep `GetxController` as a **presentation-state holder** (a ViewModel): it holds `.obs` state, calls use cases, and maps results to UI state. 🟡 [review]
- **DON'T** let a controller contain domain logic. If a controller method does real work beyond orchestration, that work belongs in a use case. 🟡 [review]
- **DO** expose reactive state as `final x = ...obs` / `Rxn<T>` fields, mutated only inside the controller. 🟡 [review]
- **DO** guard against using a disposed controller after an `await` (`if (isClosed) return;`). 🟡 [review]
- **DON'T** reference `BuildContext` across an async gap. After `await`, check `context.mounted`. 🟢 [lint: `use_build_context_synchronously`]
- **DO** prefer pattern-matching `switch` over `Result` for outcome handling in controllers (modern Dart 3 idiom). 🟡 [review]

---

## 9. Dependency Injection (Bindings)

- **DO** wire DI through GetX **Bindings**, one per feature/route. 🟡 [review]
- **DO** bind interfaces to implementations: `Get.lazyPut<HistoryRepository>(() => HistoryRepositoryImpl(...))`. The rest of the app depends on `HistoryRepository`. 🟡 [review]
- **PREFER** `Get.lazyPut` (created on first use) for feature-scoped dependencies; reserve `Get.put` for eager/app-level singletons and `Get.putAsync` for async init ([GetX DI docs](https://github.com/jonataslaw/getx/blob/master/documentation/en_US/dependency_management.md)). 🟡 [review]
- **DO** guard re-registration where bindings can run more than once (`if (!Get.isRegistered<T>())`). 🟡 [review]
- **DON'T** construct dependencies with `new`/direct instantiation inside a consumer when they should be injected. 🟡 [review]

---

## 10. Clean Code Rules (Dart)

From R.C. Martin's *Clean Code* ([summary](https://gist.github.com/wojteklu/73c6914cc446146b8b533c0988cf8d29), [Dart adaptation](https://github.com/williambarreiro/clean-code-dart)).

**Names**

- **DO** use intention-revealing, pronounceable, searchable names. A name that needs a comment is a bad name. 🟡 [review]
- **DO** name classes/types as noun phrases; functions/methods as verb phrases. 🟡 [review] ([Effective Dart: Design](https://dart.dev/effective-dart/design))
- **DON'T** use Hungarian/type-prefix encodings or single-letter names (except loop indices / well-known math). 🟡 [review]

**Functions**

- **DO** keep functions small and doing **one thing** at one level of abstraction. 🟡 [review]
- **PREFER** ≤ 2 positional parameters. At 3+, use a **parameter object** or **named parameters**. 🟡 [review]
- **DON'T** use boolean flag parameters that switch a function's behavior — split into two functions or use a named enum. 🟡 [review]
- **DO** apply **Command–Query Separation**: a method either changes state (returns `void`) or returns data (no side effects), never both ([CQS](https://en.wikipedia.org/wiki/Command%E2%80%93query_separation)). 🟡 [review]

**Side effects & DRY**

- **AVOID** mutating input arguments or hidden global state. Return new collections (`[...list, item]`) rather than mutating. 🟡 [review]
- **DO** keep each piece of logic in a single place (DRY). 🟡 [review]

**Comments**

- **DON'T** comment bad code — rewrite it. **DON'T** leave commented-out code or redundant comments that restate the code. 🟡 [review]
- **DO** use `///` doc comments to explain *why*, starting with a one-sentence summary. 🟢 [lint: `slash_for_doc_comments`] ([Effective Dart: Documentation](https://dart.dev/effective-dart/documentation))

---

## 11. Dart 3.x Idioms

Dart 3 features that are stable and **expected** in 2026 idiomatic code:

- **DO** use **`sealed` classes + exhaustive `switch`** for closed type hierarchies (`Result`, `Failure`, view states). The compiler enforces exhaustiveness. ([Class modifiers](https://dart.dev/language/class-modifiers))
- **DO** use **pattern matching** — `switch` expressions, destructuring (`case Ok(:final value)`), and `if-case`. 🟡 [review]
- **CONSIDER** **records** (`(int, String)`) for ad-hoc grouped return values instead of one-off classes — but **PREFER a named type** when the shape is part of a domain entity or crosses a public API. 🟡 [review]
- **DO** use **class modifiers** (`final`, `base`, `interface`, `sealed`) to express subtyping intent explicitly where it matters. 🟡 [review]
- **CONSIDER** **dot shorthands** (`.running`) where the context type is obvious (e.g. enum values in `switch`). 🟡 [review]
- **DON'T** rely on **experimental** features (e.g. primary constructors) in shipped code. 🟡 [review]

> **Version note (verified).** Sound null safety is the only mode. `WidgetState*` (formerly `MaterialState*`) has been the idiomatic name **since Flutter 3.19 (2024)** — use `WidgetState*`. Material 3 is the **default** theme (`useMaterial3: true` is redundant). Claims that a specific recent release made Impeller the *only* Android renderer or moved Material/Cupertino out of the SDK are **not confirmed by official release notes** and must not be treated as rules. ([Release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0), [WidgetState rename](https://docs.flutter.dev/release/breaking-changes/material-state))

---

## 12. Effective Dart: Style, Usage, Design, Docs

Canonical: [dart.dev/effective-dart](https://dart.dev/effective-dart). Highlights that matter for review (most are also lint-enforced — see §13):

- **DO** `UpperCamelCase` for types/extensions; `lowerCamelCase` for members/variables/**constants**; `lowercase_with_underscores` for files/dirs/imports. 🟢 [lint]
- **DO** order directives: `dart:` → `package:` → relative; exports in their own section; each section sorted. 🟢 [lint: `directives_ordering`]
- **DO** annotate return types and parameter types on **declarations**; **DON'T** redundantly annotate initialized locals or function-expression params. 🟢 [lint: `always_declare_return_types`]
- **AVOID** `dynamic`; prefer `Object?`. 🟢 [lint: `strict-raw-types`, `avoid_dynamic_calls` (opt-in)]
- **PREFER** `final` fields and locals; initialize fields at declaration; use initializing formals (`this.x`). 🟢 [lint: `prefer_final_fields`, `prefer_final_locals`, `prefer_initializing_formals`]
- **PREFER** `async`/`await` over raw futures; **DON'T** leave futures unawaited unintentionally. 🟢 [lint: `unawaited_futures`]
- **AVOID** positional boolean parameters; name boolean params and start their docs with "Whether…". 🟡 [review]
- **DO** override `hashCode` whenever you override `==`. 🟢 [lint: `hash_and_equals`]
- **DO** format with `dart format`; **PREFER** ≤ 80-char lines. 🟢 [lint: `require_trailing_commas` recommended]

---

## 13. Lint Policy

**Baseline:** `include: package:flutter_lints/flutter.yaml` plus `analyzer.language: { strict-casts, strict-raw-types }`. 🟢 [lint]

**Showcase-grade additions** — these are **not** in `flutter_lints` and must be enabled explicitly (this is the gap most projects miss):

- `prefer_const_constructors` — ⚠️ **not** in `flutter_lints` (only `prefer_const_constructors_in_immutables` is). **Must** be enabled.
- `prefer_const_literals_to_create_immutables`, `prefer_const_declarations`
- `require_trailing_commas`
- `prefer_final_locals`, `prefer_final_fields`
- `unawaited_futures`, `await_only_futures`
- `always_declare_return_types`
- `prefer_single_quotes`
- `avoid_print` (use a logger), `avoid_relative_lib_imports`
- `cancel_subscriptions`, `close_sinks` (resource hygiene)
- `use_super_parameters`, `use_rethrow_when_possible`, `unnecessary_*` family

**Import policy decision (mutually exclusive — pick one):** this project uses **relative imports within `lib/`** (Effective Dart's preference), enforced by *not* enabling `always_use_package_imports`. The stricter `very_good_analysis` house style chooses the opposite (`always_use_package_imports`). Either is defensible; **be consistent** and don't mix. 🟢 [lint]

**Optional stricter standard:** `very_good_analysis` (v10.x) raises the bar further (`public_member_api_docs`, `lines_longer_than_80_chars`, `always_use_package_imports`, `sort_constructors_first`, `omit_local_variable_types`). Adopting it is a project choice; if adopted, the import-policy decision above flips. ([very_good_analysis](https://pub.dev/packages/very_good_analysis))

**Rule:** No `// ignore:` or `// ignore_for_file:` without a trailing justification comment on the same or preceding line. 🟡 [review]

---

## 14. Widget & Build Discipline

From [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices).

- **PREFER** extracting a `StatelessWidget` **subclass** over a `Widget`-returning helper method. Subclasses get `const` caching, independent rebuild boundaries, and `RepaintBoundary` benefits; helper methods rebuild with the parent. 🟡 [review]
- **DO** mark widget constructors `const` and pass `const` arguments wherever possible. 🟢 [lint: `prefer_const_constructors`]
- **DO** add a `Key? key` (super-param) to public widget constructors. 🟢 [lint: `use_key_in_widget_constructors`]
- **DO** keep `build()` pure and cheap — no IO, no network, no heavy compute, no controller/listener allocation. Create those in `initState`/fields; dispose in `dispose`. 🟡 [review]
- **DO** use `SizedBox` for whitespace, not `Container`. 🟢 [lint: `sized_box_for_whitespace`]
- **DON'T** wrap children in unnecessary `Container`s. 🟢 [lint: `avoid_unnecessary_containers`]
- **DO** sort `child`/`children` last in widget argument lists. 🟢 [lint: `sort_child_properties_last`]
- **DON'T** put logic in `createState()`. 🟢 [lint: `no_logic_in_create_state`]
- **DO** use `Key`s (`ValueKey`/`ObjectKey`) when reordering/inserting/removing same-typed stateful widgets in a list — but only where element identity matters. 🟡 [review]

---

## 15. Performance

- **DO** use lazy builders (`ListView.builder`, `GridView.builder`) for long/variable lists — never a concrete child list when most children are offscreen. 🟡 [review]
- **DO** localize `setState`/reactive rebuilds to the smallest subtree (`Obx` around only the reactive part). 🟡 [review]
- **DO** offload heavy CPU work (image decode/encode, pixel ops) to an **isolate** (`Isolate.run`) so the UI thread stays at frame budget. 🟡 [review]
- **DO** wrap frequently-repainting subtrees in `RepaintBoundary` to isolate them from static siblings. 🟡 [review]
- **AVOID** `Opacity` in animations (use `AnimatedOpacity`/`FadeInImage`); use `saveLayer`, clipping, and intrinsic passes sparingly. 🟡 [review]
- **DO** cache decoded images and bound cache size; release large buffers when leaving a screen. 🟡 [review]
- **Frame budget:** build + raster ≤ 16 ms at 60 Hz. 🟡 [review]

---

## 16. Testing & Testability

Official taxonomy ([docs.flutter.dev/testing/overview](https://docs.flutter.dev/testing/overview)): **unit** (one function/class), **widget** (one widget), **integration** (full app). *"Many unit and widget tests, plus enough integration tests to cover important use cases."*

- **DO** mirror `lib/` under `test/`; test files end in `_test.dart`. 🔵 [test] ([cookbook](https://docs.flutter.dev/cookbook/testing/unit/introduction))
- **DO** unit-test every **use case** with a mocked repository, and every **repository impl** with mocked datasources/services — *mock everything except the class under test*. 🔵 [test]
- **DO** unit-test controllers by mocking their **use cases** (enabled by constructor injection). 🔵 [test]
- **DO** use **`mocktail`** (null-safe, no codegen) for mocks. 🔵 [test] ([mocktail](https://pub.dev/packages/mocktail))
- **DO** reset GetX global state between tests (`Get.reset()` / `Get.testMode = true`). 🔵 [test]
- **DO** write **widget tests** for non-trivial pages/widgets (states: loading, error, success, empty). 🔵 [test]
- **Coverage target:** **VGV recommends 100% line coverage** enforced in CI (`--coverage --min-coverage`) ([VGV](https://verygood.ventures/blog/road-to-100-test-coverage/)). **Our minimum:** **100% on `domain/` and `data/`** (pure, deterministic, high-value), with widget/controller coverage tracked and trending up. Generated files (`*.g.dart`) are excluded. 🔵 [test]
- **DON'T** ship a feature whose use cases/repository are untested. 🔵 [test]

> **Testability is the proof of the architecture.** If a use case can't be unit-tested without spinning up Hive/ML Kit/the camera, the dependency inversion is broken — fix the design, not the test.

---

## 17. Definition of Done (Audit Checklist)

A feature/PR is "done" only when **all** of the following hold. This is the checklist the audit phase runs against.

**Architecture**
- [ ] `domain/` has no Flutter/GetX/Hive/IO imports (grep-clean).
- [ ] Repository **interface** in `domain/`, **impl** in `data/`; presentation depends on the interface.
- [ ] Business operations go through **use cases** (`call()`); controllers only orchestrate.
- [ ] Entities and data models are separate; mapping lives in the repository impl.

**Error handling**
- [ ] All repo/use-case methods return `Result<T>` (or `Either`); no exceptions cross into presentation.
- [ ] `Failure` is a sealed hierarchy; results are consumed via exhaustive `switch`.
- [ ] No bare `catch` discards an error; IO catches log + convert to `Failure`.

**GetX discipline**
- [ ] `Get.find()` appears **only** in Bindings.
- [ ] No business logic/IO in controllers or widgets.
- [ ] Controllers scoped via Bindings; no stray permanent/global controllers.

**Clean Code & style**
- [ ] `flutter analyze` is clean with the showcase lint set; no unjustified `// ignore:`.
- [ ] Functions small, single-purpose; ≤2 positional params or a param object; no flag args.
- [ ] No commented-out code; doc comments explain *why*.
- [ ] snake_case files mirroring their primary type.

**Widgets & perf**
- [ ] `const` constructors used; `build()` is side-effect-free; lists use `.builder`.
- [ ] Heavy CPU work is in isolates.

**Tests**
- [ ] `test/` mirrors `lib/`; use cases + repos tested with `mocktail`.
- [ ] Domain/data at 100% coverage; GetX global state reset between tests.

---

## 18. Sources

**Clean Architecture & SOLID (primary)**
- Uncle Bob — [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) · [Principles of OOD](http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod) · [An Open and Closed Case](https://blog.cleancoder.com/uncle-bob/2013/03/08/AnOpenAndClosedCase.html)
- [Dependency Inversion Principle (Wikipedia)](https://en.wikipedia.org/wiki/Dependency_inversion_principle) · [SOLID (Wikipedia)](https://en.wikipedia.org/wiki/SOLID)

**Clean Architecture for Flutter**
- Reso Coder — [Flutter TDD Clean Architecture: Project Structure](https://resocoder.com/2019/08/27/flutter-tdd-clean-architecture-course-1-explanation-project-structure/)
- Code With Andrea — [Repository Pattern](https://codewithandrea.com/articles/flutter-repository-pattern/) · [Domain Model](https://codewithandrea.com/articles/flutter-app-architecture-domain-model/) · [Project Structure](https://codewithandrea.com/articles/flutter-project-structure/) · [Functional Error Handling](https://codewithandrea.com/articles/functional-error-handling-either-fpdart/)
- Very Good Ventures — [Very Good Flutter Architecture](https://verygood.ventures/blog/very-good-flutter-architecture/) · [Engineering Handbook](https://engineering.verygood.ventures/architecture/)
- Official Flutter — [App Architecture Guide](https://docs.flutter.dev/app-architecture/guide) · [Result pattern](https://docs.flutter.dev/app-architecture/design-patterns/result)

**Clean Code**
- [Clean Code summary (wojteklu)](https://gist.github.com/wojteklu/73c6914cc446146b8b533c0988cf8d29) · [clean-code-dart](https://github.com/williambarreiro/clean-code-dart) · [Command–Query Separation](https://en.wikipedia.org/wiki/Command%E2%80%93query_separation)

**Effective Dart & Lints**
- [Effective Dart](https://dart.dev/effective-dart) (Style/Usage/Design/Documentation) · [Linter rules](https://dart.dev/tools/linter-rules)
- [flutter_lints](https://pub.dev/packages/flutter_lints) · [lints](https://pub.dev/packages/lints) · [very_good_analysis](https://pub.dev/packages/very_good_analysis)

**Dart 3 / Flutter framework**
- [Class modifiers](https://dart.dev/language/class-modifiers) · [Dot shorthands](https://dart.dev/language/dot-shorthands) · [Release notes 3.44](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0) · [WidgetState rename](https://docs.flutter.dev/release/breaking-changes/material-state)

**Performance & Testing**
- [Performance best practices](https://docs.flutter.dev/perf/best-practices) · [RepaintBoundary](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)
- [Testing overview](https://docs.flutter.dev/testing/overview) · [Unit test intro](https://docs.flutter.dev/cookbook/testing/unit/introduction) · [mocktail](https://pub.dev/packages/mocktail) · [VGV — Road to 100% coverage](https://verygood.ventures/blog/road-to-100-test-coverage/)

**GetX**
- [pub.dev/packages/get](https://pub.dev/packages/get) · [GetX DI docs](https://github.com/jonataslaw/getx/blob/master/documentation/en_US/dependency_management.md) · [Clean Architecture with GetX](https://blog.adityasharma.co/building-flutter-apps-with-clean-architecture-using-getx) · GetX critiques: [1](https://medium.com/@darwinmorocho/flutter-should-i-use-getx-832e0f3a00e8) · [2](https://medium.com/@mdriazofficial/building-scalable-flutter-apps-with-getx-lessons-pitfalls-and-fixes-f426c8eda11a)

---

*This document reflects authoritative sources as verified in 2026. Where a premise about a specific Flutter release could not be confirmed against official release notes, the conservative (officially-documented) position was taken and flagged inline.*
