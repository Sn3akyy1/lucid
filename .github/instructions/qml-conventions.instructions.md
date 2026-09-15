---
applyTo: "**/*.qml"
description: "Guidelines and conventions for QML and Quickshell components in Lucid"
---

# QML Conventions for Lucid

When creating or modifying QML components in Lucid:

## Component Structure & Identification

- Always assign a clear `id` to the top-level element (e.g. `id: root`, `id: w`, `id: page`).
- Singletons must include `pragma Singleton` at line 1 and use `Singleton { id: root }` as the root element.

## Imports

- Import global singletons using `import qs`.
- Quickshell system imports: `import Quickshell`, `import Quickshell.Io`, `import Quickshell.Hyprland`, `import Quickshell.Services.SystemTray`, `import Quickshell.Wayland`.

## Design System & Styling

- **Colors**: Always reference `Theme` roles:
  - Backgrounds: `Theme.bg`, `Theme.cContainer`, `Theme.cSurface`
  - Text & Icons: `Theme.text`, `Theme.subtext`, `Theme.cOnPrimary`
  - Accents & Highlights: `Theme.cPrimary`, `Theme.accent`, `Theme.outline`
- **Border Radius**: `Theme.radiusSm`, `Theme.radiusMd`, `Theme.radiusLg`, `Theme.radiusPill`.
- **Motion**: Use `NumberAnimation` / `Behavior on <property>` with `easing.type: Easing.OutCubic` or `Theme.easeEmphasized`, and durations `Theme.durQuick`, `Theme.durShort`, `Theme.durMedium`.

## IPC Handlers

- Component IPC handlers should use `IpcHandler`:
  ```qml
  IpcHandler {
      target: "feature"
      function toggle() { ... }
  }
  ```

## State & File Persistence

- State storage should use `FileView` + `JsonAdapter`.
- Resolve home folder dynamically using `Quickshell.env("HOME")`.
