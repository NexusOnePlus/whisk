# Whisk Design System (Liquid Glass Edition)

> Focused authoring workspace with a premium macOS 26 / Liquid Glass aesthetic.

Whisk uses a "Liquid Glass" interface: a deep, translucent environment optimized for long writing sessions. The UI feels like a high-end physical workstation—using glass, subtle refractions, and deep shadows to create a sense of depth and precision.

## Visual Direction: Liquid Glass

The visual language borrows from the "macOS 26" concept:
- **Translucency**: Surfaces use `BackdropFilter` with a 20px+ blur.
- **Refraction**: Borders are not solid colors but 1px linear gradients that simulate light hitting a glass edge.
- **Depth**: Panels use multiple shadows—a soft outer drop shadow and a subtle inner highlight to define volume.
- **Squircles**: All rounded corners use a high-radius squircle (18px-24px) for a more organic, premium feel.

## Colors

| Name | Value | Role |
| --- | --- | --- |
| Deep Black | `#080A0C` | Main app background (under glass) |
| Glass Base | `#11151B` | Base color for glass panels (low opacity) |
| Glass Highlight | `#FFFFFF1A` | Top-left edge gradient for glass refraction |
| Glass Shadow | `#00000033` | Bottom-right edge gradient for glass depth |
| Border Nuance | `#2A323D` | Default subtle divider color |
| Text Primary | `#F5F7FA` | Main labels and active content |
| Text Secondary | `#A8B0BA` | Descriptions, metadata, inactive labels |
| Text Muted | `#69717D` | Line numbers, placeholders, disabled state |
| Liquid Blue | `#479FFA` | Primary accent, focus, active environment |
| Liquid Amber | `#FFA16C` | Warnings, render attention, highlights |
| Liquid Success | `#4EBE96` | Render success, connected peers |
| Liquid Danger | `#FF6673` | Errors and destructive actions |

## Typography

- **UI Font**: Inter or System Sans (`Segoe UI`).
- **Source Font**: `JetBrains Mono`, `Consolas`, or `Roboto Mono`.
- **Weight**: UI labels use `FontWeight.w500` or `w600` for better definition on blurred backgrounds.
- **Editor**: Stable 14px with 1.5 line height.

## Layout & Forms

- **Gaps**: Use consistent 12px / 24px spacing ("bento box" style).
- **Floating capsules**: Command bars and window controls should feel like floating glass objects.
- **Forms**: Input fields use the "Inner Shadow" effect to look recessed into the glass surface.

## Components

### Glass Panel

The core building block of Whisk.
- **Background**: `kGlassBase.withOpacity(0.7)` + `BackdropFilter(sigma: 24)`.
- **Border**: `GradientBorder` (Top-Left: `kGlassHighlight`, Bottom-Right: `kGlassShadow`).
- **Shadow**: Medium-blur drop shadow (`Color(0x66000000)`, blur: 16).

### Window Frame

Global floating horizontal capsule for minimize/maximize/close.
- Inspired by macOS 26 minimalist design.
- Compact, high-contrast controls.

### Sidebar (File Explorer)

The sidebar is a tall glass panel that "floats" over the workspace rail.
- **Sync Hook**: Must be reactively tied to the `WorkspaceViewModel`.
- **Active Row**: Uses a "Liquid Glow" effect—a subtle gradient background with a high-intensity accent edge.

### Source Editor

The "Zed-like" core.
- **Multi-cursor**: Primary cursor is `Liquid Blue`, secondary cursors are `Liquid Amber`.
- **Virtualization**: Only render lines and decorations within the `visibleLineRange`.
- **Typography**: Clean, high-density monospaced text.

## Do

- Use gradients for borders to simulate glass edges.
- Add `BackdropFilter` to all primary panels.
- Use squircle corners (18px+) for all containers.
- Keep the interface "quiet" but "premium" through subtle animations.

## Don't

- Use flat, solid-color borders.
- Use sharp 90-degree corners.
- Use opaque backgrounds for floating panels.
- Overuse saturated colors—reserve them for accents and glows.
