# Whisk Architecture

Whisk is a multi-platform authoring workspace for renderable source files. It is not a general code IDE. The app should stay centered on files, render engines, diagnostics, preview, collaboration and exports.

Primary target: Windows. Secondary targets: Android and web.

## Goals

- Open and manage workspaces made of real files.
- Select behavior by file type and environment adapter.
- Render LaTeX, Typst, Mermaid, Markdown and future formats.
- Support large source files without editor lag or full-document repainting.
- Support real-time collaboration with remote cursors and selections.
- Keep local-first workflows while allowing future cloud sync.
- Keep platform-specific engine details outside UI widgets.

## Non-Goals

- Do not become a full IDE clone.
- Do not expose mixed document blocks as the main user model.
- Do not couple Whisk to one editor package, render engine or collaboration transport.
- Do not call native processes, cloud APIs or Rust bridge code directly from UI widgets.

## Product Model

The user model is file-based:

```text
Workspace
  paper.tex       -> LaTeX environment
  report.typ      -> Typst environment
  flow.mmd        -> Mermaid environment
  notes.md        -> Markdown environment
```

Each file has one active environment selected by extension or metadata. A workspace may contain multiple environment types, but each file is rendered by its own adapter.

## Layering

Current base structure:

```text
lib/
  data/
    repositories/
  domain/
    models/
  ui/
    core/
    features/
```

Target structure as the app grows:

```text
lib/
  data/
    repositories/
      workspace_repository.dart
      environment_repository.dart
      render_repository.dart
      collaboration_repository.dart
      sync_repository.dart
    services/
      local_file_service.dart
      platform_process_service.dart
      cloud_api_service.dart
      collaboration_transport_service.dart
  domain/
    models/
      whisk_workspace.dart
      whisk_file.dart
      environment_kind.dart
      render_result.dart
      document_diagnostic.dart
      presence_cursor.dart
    adapters/
      environment_adapter.dart
      render_engine.dart
      source_editor_adapter.dart
      collaboration_adapter.dart
    use_cases/
      open_workspace.dart
      render_active_file.dart
      apply_remote_edit.dart
      sync_workspace.dart
  ui/
    core/
      whisk_theme.dart
      whisk_colors.dart
      shared_widgets/
    features/
      workspace/
      editor/
      preview/
      diagnostics/
      collaboration/
      settings/
```

## Dependency Direction

UI depends on ViewModels.
ViewModels depend on domain use cases or repositories.
Repositories depend on services/adapters.
Services depend on platform/cloud packages.

Domain models must not import Flutter UI packages except when there is a deliberate UI-facing model. Prefer keeping domain models plain Dart.

## Shell Layout

Dashboard mode uses one global navigation rail:

```text
WorkspaceRail | Dashboard
```

The dashboard is where users create projects, reopen recent workspaces, manage packages/adapters, see friends/collaboration and access settings.

Editor mode uses the same global rail plus project-local editor chrome:

```text
WorkspaceRail | ContextualSidebar | Editor | Preview
```

`WorkspaceRail` is app-level navigation and keeps stable meaning across the app. `ContextualSidebar` appears after a project is opened and can be collapsed. It changes according to the active rail item, active project and active environment. Editor tabs live above the editor, not in the global sidebar.

Compact layouts may collapse the rail/sidebar into tabs or sheets, but the same conceptual split remains.

## Environment Adapter

Every supported format should enter through an adapter:

```dart
abstract class EnvironmentAdapter {
  String get id;
  String get displayName;
  Set<String> get extensions;

  Future<RenderResult> render(RenderRequest request);
  Future<List<DocumentDiagnostic>> analyze(String content);
}
```

Examples:

- `LatexEnvironmentAdapter`
- `TypstEnvironmentAdapter`
- `MermaidEnvironmentAdapter`
- `MarkdownEnvironmentAdapter`

Adapters can use different implementations per platform. For example, LaTeX may use a bundled Windows binary, a server renderer on web, and a restricted local/remote renderer on Android.

## Rendering

Rendering is a repository/use-case concern, not a widget concern.

Flow:

```text
UI render button
  -> WorkspaceViewModel.renderActiveFile()
  -> RenderActiveFile use case
  -> RenderRepository
  -> EnvironmentAdapter
  -> platform engine/service
  -> RenderResult + diagnostics
```

`RenderResult` should normalize outputs:

- success/failure
- output type: PDF, SVG, HTML, image, text
- bytes or URI
- diagnostics
- logs
- source engine

## Diagnostics

All engine errors should become normalized diagnostics:

```dart
class DocumentDiagnostic {
  final String filePath;
  final int line;
  final int column;
  final int length;
  final DiagnosticSeverity severity;
  final String message;
  final String source;
}
```

The editor, gutter, diagnostics panel and status bar consume this shared model. Engine-specific logs should not leak into widgets except as secondary details.

## Source Editor

Whisk should own the editor abstraction. We may implement it ourselves or swap internals later, but the app should depend on a stable Whisk interface.

Required capabilities:

- large file support;
- stable scroll performance;
- visible-line virtualization;
- incremental syntax highlighting;
- cached line/chunk spans;
- diagnostics decorations;
- remote cursors and selections;
- search decorations;
- editor lens/actions;
- undo/redo;
- keyboard shortcuts;
- copy/paste;
- IME support where practical.

The editor must avoid:

- recoloring the full document on every keystroke;
- rebuilding all lines on scroll;
- computing cursor positions with fixed-width guesses if the renderer can provide real rects;
- using plain `TextField` as the final source editor.

Initial implementation can be simple, but the abstraction should assume a future rope or piece-table buffer.

## Collaboration

Collaboration is scoped by workspace and active file.

Separate these channels:

- document operations;
- presence/awareness;
- initial file sync;
- binary asset sync;
- comments or annotations;
- connection/session state.

Recommended domain models:

```dart
class PresenceCursor {
  final String peerId;
  final String filePath;
  final int offset;
  final int selectionBase;
  final int selectionExtent;
}
```

The old Kitex Rust/Yrs/Iroh direction is useful, but should return as an adapter, not as app-global state directly attached to the screen.

Potential adapters:

- local-only collaboration simulator for tests;
- P2P adapter for Windows desktop;
- cloud relay adapter for web and mobile;
- future team/workspace cloud adapter.

## Cloud Readiness

Cloud should be introduced behind repositories:

- `WorkspaceRepository`: local and cloud workspace metadata.
- `SyncRepository`: upload/download, conflict policy, offline queue.
- `AccountRepository`: auth/session/team identity.
- `CollaborationRepository`: active sessions and live operations.

The UI should not know whether a workspace is local-only, cloud-backed or shared. It should observe workspace state and sync state.

Sync states:

- local only;
- syncing;
- synced;
- offline edits pending;
- conflict;
- remote unavailable;
- permission denied.

## Platform Strategy

### Windows

Primary platform. Can use local binaries, Rust bridge, file system access and desktop-specific window behavior. Windows uses floating custom window controls instead of the native titlebar. Drag regions should be explicit chrome surfaces such as the rail/sidebar.

### Android

Must assume restricted file system access and heavier engine constraints. Prefer document picker/storage providers, sandboxed workspace cache and optional cloud renderers.

### Web

Cannot rely on native binaries or unrestricted file access. Use browser storage, uploaded workspaces, service/cloud rendering or WebAssembly where feasible.

## Testing Strategy

Early tests:

- ViewModel unit tests for environment switching and active file state.
- Widget tests for responsive workspace layout.
- Repository tests with fake services.

Later tests:

- editor buffer tests;
- diagnostics mapping tests per engine;
- renderer adapter tests;
- collaboration operation merge tests;
- golden/widget tests for large diagnostics and presence overlays.

## Current State

Implemented:

- Flutter project for Windows, Android and web.
- Dark Whisk design system.
- Initial workspace shell.
- Environment catalog for LaTeX, Typst, Mermaid and Notes.
- Basic layered structure with domain, data and UI.

Still pending:

- real workspace/file repository;
- custom source editor;
- render adapter contracts;
- diagnostics model;
- collaboration adapter contracts;
- platform service boundaries;
- cloud sync contracts.

## Next Implementation Steps

1. Add domain contracts for render results, diagnostics and environment adapters.
2. Replace sample-only state with an in-memory workspace repository.
3. Build a first Whisk-owned `SourceEditor` abstraction.
4. Implement a virtualized read/edit prototype for source lines.
5. Add fake render adapters for LaTeX, Typst and Mermaid.
6. Add diagnostics decorations using fake engine errors.
7. Add collaboration presence models before transport.
8. Only then evaluate Rust/native engines and cloud transport.
