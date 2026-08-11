## 0.0.5

* **Native Double-Tap Maximization**:
  - Replaced custom tap interval logic with native `GestureDetector(onDoubleTap)` behavior matching the tab maximize button, ensuring cross-device support (mouse, trackpad, and touch screen).
* **Maximize Geometry Safety**:
  - Prevented window drag/resize events from occurring on maximized windows to safeguard geometry and prevent layout corruption.
  - Fixed single-click header events on maximized windows from incorrectly unmaximizing them by preventing `bringToFront` from triggering force-unmaximization.
  - Fixed focus-rebuild race conditions by removing redundant re-maximization focus change listeners.
* **Maximize Close-Transition Integration**:
  - Synchronized window focus transitions so that when the active maximized window is closed, the newly focused window automatically maximizes if global maximize mode is active.
* **Developer Diagnostics**:
  - Added robust test coverage asserting single-click integrity on maximized headers and seamless state maximization transitions on window closures.
  - Resolved static analysis warnings by deleting unused variables/extensions and renaming private `_EdgeSide` and `_CornerSide` enums to public `EdgeSide` and `CornerSide`.

## 0.0.4

* **Performance Optimization**:
  * Implemented window widget caching within `ResizeableWindowController` to avoid rebuilding window chromes on sibling updates or Z-order changes.
  * Deferred MDI canvas screen size calculations to post-frame callbacks to avoid build phase layout conflicts.
  * Streamlined tab scroll checking by invoking it only on tab mutations instead of every frame rebuild.
  * Removed the redundant 100ms async notification delay when adding new windows, making window opening instantaneous.
* **Workspace Persistence**:
  * Added `MdiController.exportLayout()` to serialize window geometries, Z-orders, and arguments to JSON.
  * Added `MdiController.importLayout()` with diff-based reconciliation to restore layout configurations in-place, keeping active controller instances (and their widget states) intact.
* **Magnetic Edge Snapping**:
  * Added snapping bounds math that aligns dragging window boundaries and resizing edges to adjacent window borders or screen edges within a 12px range.
* **Platform-Aware Keyboard Accessibility**:
  * Added support for `Ctrl + Tab` / `Ctrl + Shift + Tab` (cycling focus) and `Ctrl + W` / `Ctrl + F4` (closing window) on Native builds.
  * Added web-safe fallback shortcuts (`Ctrl + .` / `Ctrl + ,` and `Alt + W`) for Web builds to avoid browser hotkey collisions.
* **Demo Showcase Update**:
  * Added a stateful interactive `CalculatorWidget` to demonstrate MDI state preservation during Z-order changes and layout imports.
  * Rebuilt the example dashboard layout with MDI layout control center, serialization persistence, and a platform-aware shortcuts guide.

## 0.0.1

* Initial release of MDI View package.
* Added MdiController for window management.
* Added MdiManager widget for rendering the workspace.
* Added support for resizable, maximizable, and draggable windows.