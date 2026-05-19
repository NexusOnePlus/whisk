# Whisk

Whisk is a Flutter workspace for focused authoring environments.

The first target is Windows, with Android and web kept enabled from the start.
The app is intentionally starting small: a stable shell, environment switching,
source input and a preview area ready for renderer adapters.

## Initial Environments

- LaTeX (`.tex`)
- Typst (`.typ`)
- Mermaid (`.mmd`)
- Notes / Markdown (`.md`)

## Architecture

The project starts with a layered Flutter structure:

```text
lib/
  data/        # repositories and future local/cloud services
  domain/      # app models such as files and environments
  ui/
    core/      # theme, tokens and shared UI primitives
    features/  # feature screens, widgets and view models
```

Render engines, collaboration transport, local storage and future cloud sync
should enter through repositories/adapters instead of being called directly from
widgets. This keeps Windows, Android and web support viable as the engine stack
diverges by platform.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the detailed plan.

## Development

```powershell
flutter pub get
flutter run -d windows
```

For now, avoid pulling in the old Kitex Rust/PDF/editor stack directly. Those
pieces should return as isolated adapters once the product shell is stable.
