# AGENTS.md

These instructions apply throughout `app/` and supplement the [root instructions](../AGENTS.md), including the review checkpoint after each TDD step.

## Hexagonal architecture

- Keep dependencies pointing inward. Flutter UI and infrastructure adapters depend on the application core through its public contracts. Keep domain rules, application behavior, and port interfaces independent of Flutter, HTTP, storage, and platform APIs.
- Define repository and authentication ports in `lib/app/` using application and domain terms. Reuse the models from `package:shared/model.dart`. Put business rules and invariants in the core. Introduce a use case when a workflow needs orchestration or shared business rules.
- Put backend and platform adapters in `lib/data/`. Implement application ports there and translate transport data and failures at the boundary. Use the shared `TwApiClient` for backend calls.
- Keep real and fake adapter selection in `lib/main.dart`. Inject ports through constructors and the existing `RepositoryProvider` above the navigator. `TwApp` and `RepositoryProvider` are Flutter wiring, even though their files are in `lib/app/`.

## Flutter best practices

- Follow the [official Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) within the dependency rules above. Use feature-based views and view models or controllers in `lib/ui/`. Keep widgets focused on rendering, layout, navigation, dialogs, and forwarding user actions. Reuse existing view models and controllers where they fit.
- Expose immutable presentation state and keep data flow unidirectional. User actions go through methods or callbacks, and widgets render the resulting state. Keep `build` free of side effects and start loads at the appropriate lifecycle boundary.
- Dispose state objects where they are owned. Check `mounted` before using a `BuildContext` after an asynchronous gap. Guard view-model updates against disposal and stale completions when requests can overlap.
- Import Material widgets from `package:material_ui/material_ui.dart`. Reuse existing UI components and support responsive layouts, semantics, and keyboard and touch interaction as required by the feature.

## Testing and verification

- Use the smallest test that proves the required behavior. Use unit tests for application and presentation logic and widget tests for rendering and interaction. Reuse in-memory repositories, screen robots, controlled futures, and fixed clocks where relevant. Skip dedicated tests for fakes and trivial adapter forwarding.
- Run the targeted test at each TDD step. Use `make test-app`, `make analyze-app`, and `make format-check-app` from the repository root for package-wide verification when applicable.
