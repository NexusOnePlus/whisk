# Whisk Design System

> Focused authoring workspace for renderable documents and diagrams.

Whisk uses a dark, quiet interface optimized for long writing and repeated review. The UI should feel like a precise document workstation: file navigation, source editing, preview, diagnostics and collaboration presence are primary surfaces. It is not a landing page and should not use marketing composition inside the app.

The visual direction should borrow from modern desktop authoring apps: compact chrome, floating pills, rounded tabs, thin dividers, useful density, and a few vivid accents. It should not look like a generic IDE. Color enters through environment chips, diagnostics, render state, collaboration badges and preview surfaces.

## Product Shape

- Primary target: Windows desktop.
- Secondary targets: Android and web.
- Main unit of work: files inside a workspace.
- Environment selection comes from file type: `.tex`, `.typ`, `.mmd`, `.md` and future adapters.
- Rendering, diagnostics, collaboration and editor features are environment-aware.

## Colors

| Name | Value | Role |
| --- | --- | --- |
| App Black | `#0B0D10` | Main app background |
| Panel | `#11151B` | Sidebar, editor and preview surfaces |
| Panel Raised | `#171C24` | Active rows, toolbar controls, elevated panels |
| Border | `#27303A` | Dividers and subtle outlines |
| Text Primary | `#F5F7FA` | Main labels and active content |
| Text Secondary | `#A8B0BA` | Descriptions, metadata, inactive labels |
| Text Muted | `#69717D` | Line numbers, placeholders, disabled state |
| Accent Blue | `#479FFA` | Active environment, focus, collaboration actions |
| Accent Amber | `#FFA16C` | Warnings, render attention, highlights |
| Coral | `#FF7759` | Comments, taxonomy chips, warm project markers |
| Violet | `#9B60AA` | Focus accents and secondary technical badges |
| Success Green | `#4EBE96` | Render success, connected peers |
| Danger Red | `#FF6673` | Errors and destructive actions |

## Typography

- UI font: system sans (`Segoe UI`, Inter fallback).
- Source font: `Consolas`, `Cascadia Mono`, `Roboto Mono`, monospace.
- Avoid negative letter spacing in app UI.
- Keep editor/source text stable at 14px with predictable line height.
- Dense panels use 11-13px metadata text.

## Layout

- Desktop app uses floating custom window controls instead of the native titlebar.
- Dashboard layout uses two stable regions: global workspace rail and dashboard content.
- Editor layout uses four stable regions: global workspace rail, collapsible editor sidebar, tabbed editor, preview.
- Compact layout stacks editor and preview below horizontal environment navigation.
- All scrollable lists must be lazy rendered.
- Avoid nested cards. Use panels and dividers for app structure.
- Keep toolbar height stable so editing and preview panes do not jump.
- Reserve right-side toolbar space for floating window controls.
- Editor source should occupy its available area directly; avoid wrapping the source editor in decorative cards.

## Components

### Window Controls

Global desktop-only floating horizontal capsule with minimize/maximize/close controls. It is not a full-width titlebar. Window dragging should happen from stable chrome surfaces such as the global rail or project sidebar, not from invisible overlay regions.

### Workspace Rail

The workspace rail is global and always means app-level navigation. It holds:

- home;
- projects;
- packages/adapters;
- friends/collaboration;
- feedback;
- help;
- settings.

This rail should not change its meaning per environment.

### Contextual Sidebar

Appears after opening a project. Used for the selected workspace tool and active environment context. It contains file navigation, diagnostics, render history, peers or environment tools depending on the active mode. It must be collapsible.
Selected rows use `Panel Raised` with an `Accent Blue` indicator.

The sidebar should include a floating segmented navbar near the top for:

- Files
- Diagnostics
- Comments
- Renders

The sidebar content must be scoped to the active project/environment. Do not list every supported environment inside the editor sidebar. Environment creation and switching between open projects belongs on the dashboard/global workspace surfaces.

### Editor Tabs

File tabs live above the editor, not inside the global sidebar. Tabs use rounded top corners and should support being reordered, detached into another window and restored later.

Tabs should feel like compact pills connected to the editor chrome:

- active tab uses `Panel`;
- inactive tabs use translucent `Panel Raised`;
- close controls are small and muted;
- unsaved state should be a small dot, not a large label.

### Editor Toolbar

The editor toolbar is one compact horizontal row above tabs/source. It should contain the project/environment identity, active file metadata, lightweight pills and common actions. Avoid repeating the environment name in multiple places.

Render controls belong near the preview area or as preview-owned actions, not as the dominant control inside the source editor header.

Suggested controls:

- environment badge;
- active output type;
- search;
- split/preview toggle;
- comments/presence;
- overflow menu.

### Source Editor

The editor must be custom or wrapped behind a Whisk-owned abstraction. It needs:

- stable line height;
- virtualized visible lines;
- cached syntax spans per line or chunk;
- decorations for diagnostics, search, lenses and remote cursors;
- no full-document recolor during typing or scroll.

### Preview

Preview panels are engine-owned. They should expose render status, diagnostics and export actions without taking over the source editor.

Preview should have its own mini-toolbar slightly separated from the rendered surface:

- Render / Stop
- Export
- Zoom
- Split mode
- Output format
- Last render status

The rendered page/canvas can be more visually expressive than the app chrome. Use subtle bento-like preview cards, status chips and environment-colored badges to avoid an empty dark rectangle.

### Diagnostics

Diagnostics normalize engine errors into file, line, column, severity and message. They appear in the editor gutter, status bar and an optional details panel.

### Collaboration

Presence is scoped to the active file. Remote cursors, selections and peer labels should be drawn as editor decorations, not inserted into source content.

## Do

- Optimize for repeat use and large files.
- Keep the app visually restrained.
- Use one primary accent color for active state.
- Add liveliness through pills, chips, badges, preview cards and environment markers.
- Keep render errors visible but not modal by default.
- Make platform-specific behavior live behind adapters.
- Use subtle translucent surfaces and blur only for floating controls or overlays.
- Let each environment have a small accent identity without changing the whole app theme.

## Don't

- Do not turn the app into a code IDE clone.
- Do not mix render engines directly into UI widgets.
- Do not add decorative gradients or large hero layouts inside the app.
- Do not make the editor toolbar repeat the same environment/file information shown elsewhere.
- Do not rely on a plain `TextField` for real source editing.
- Do not couple collaboration transport to one editor implementation.
- Do not use gradients as normal panel fills; reserve richer visual treatment for preview/output/media surfaces.

## Environment Identity

Each environment may define:

- icon;
- accent color;
- file extensions;
- preview output types;
- toolbar actions;
- diagnostics categories;
- export targets.

Initial accents:

| Environment | Accent | Notes |
| --- | --- | --- |
| LaTeX | `#479FFA` | Technical documents, PDF-first |
| Typst | `#9B60AA` | Modern documents, fast preview |
| Mermaid | `#4EBE96` | Diagrams, SVG/PNG export |
| Markdown | `#FF7759` | Notes and rich text preview |

The active environment should influence chips and tool icons, not repaint the whole shell.

## Desktop Editor Reference

The editor screen should resemble a compact desktop authoring app:

```text
Floating window controls
Workspace rail | Project sidebar | Editor toolbar
                              | Rounded file tabs
                              | Source editor | Preview toolbar
                                              | Preview surface
```

The visual emphasis should be:

- clean side navigation;
- strong active file state;
- source and preview split;
- compact pills/chips;
- minimal but useful status metadata;
- room for comments, diagnostics and collaboration without crowding source.
