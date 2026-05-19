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

## Development

```powershell
flutter pub get
flutter run -d windows
```

For now, avoid pulling in the old Kitex Rust/PDF/editor stack directly. Those
pieces should return as isolated adapters once the product shell is stable.
