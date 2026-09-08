## 0.0.8

* **Interactive Child Controls & Window Drag Bypass**:
  - Enhanced automatic hit-testing (`_shouldIgnoreDrag` / `shouldIgnoreDrag`) on `ResizeableWindowController` to detect standard and custom sliders (`Slider`, `RangeSlider`, `Thumb`, `Track`, `Scrollbar`, `Knob`), drag gesture recognizers (`RenderSemanticsGestureHandler` with active drag updates), and raw pointer listeners (`RenderPointerListener` with `onPointerMove` or `onPointerPanZoomUpdate`).
  - Added `shouldIgnoreDragTarget` (`bool Function(HitTestTarget target)?`) to `MdiStyleConfiguration` for custom application-level drag bypass rules.
  - Set `excludeFromSemantics: true` on `dragWidget`'s `GestureDetector` so window dragging mechanics do not conflict with child drag semantics.
* **Workspace Pointer Scroll Delegation & Shift+Scroll Support**:
  - Implemented automatic pointer scroll routing for non-scrollable window areas (empty space, Card, Container, background, and default window header): mouse wheel / trackpad scroll events over these areas now smoothly scroll the parent MDI canvas.
  - Retained strict scroll isolation for inner scrollable widgets (`ListView`, `SingleChildScrollView`, `TextField`, etc.), ensuring they consume scroll events without propagating to the canvas.
  - Added **Shift + Scroll** support: holding Shift while rolling the mouse wheel over non-scrollable window areas smoothly translates vertical wheel ticks into horizontal MDI workspace scrolling.
  - Ensured canvas bounds are immediately recalculated upon window registration (`_recalculateMdiSize()`) in `MdiController`.

## 0.0.7

* **Window Gesture Integration & Arena Resolution**:
  - Re-architected window body dragging (`draggableBody`) to use `GestureDetector` (via gesture arena resolution) instead of a raw `Listener`. This allows child interactive widgets (such as list views, buttons, scrollbars, and scrollbar thumbs) to naturally win gesture competition and scroll/drag/interact without dragging the window.
  - Retained raw `Listener` behavior specifically for the unfocus blocker to maintain seamless click-focus-and-drag mechanics when the window is clicked while unfocused.
* **Scope Isolation for Scroll Physics**:
  - Moved the hover-driven MDI scroll physics lock (`NeverScrollableScrollPhysics`) directly to the MDI canvas's `SingleChildScrollView`s rather than applying it globally via the inherited `ScrollConfiguration`. This isolates gesture locks to the canvas level, keeping child scroll views inside windows fully interactive.

## 0.0.6

* **Pointer Drag Interception & Ignore Mechanics**:
  - Introduced the `IgnoreWindowDrag` widget to explicitly wrap interactive child components (such as WebViews, maps, or drawing canvases) and prevent parent MDI window dragging.
  - Implemented automatic pointer down hit-testing that traverses the child render tree to detect viewports (`RenderAbstractViewport`), platform views (covering `InAppWebView`, native maps, etc.), and text inputs (`RenderEditable` and `_RenderDecoration`), automatically bypassing window dragging over these areas.
* **Scroll & Pointer Signal Propagation Blocking**:
  - Implemented an elegant, hover-driven canvas scroll protection model tracking window pointer entries and exits, dynamically disabling background MDI canvas scroll gestures when the user's cursor is over any window.
  - Wrapped window content areas with `NotificationListener<ScrollNotification>` to prevent child scroll/overscroll bubble notifications from reaching the MDI canvas.
  - Intercepted `PointerScrollEvent`s (mouse wheel and trackpad scroll signals) at the window boundary using `PointerSignalResolver` to consume them locally, preventing desktop canvas scrolling.
* **Diagnostics & Demos**:
  - Added new widget test suites validating explicit `IgnoreWindowDrag` behavior, automatic scrollable drag bypasses, text input drag bypasses, and scroll propagation boundaries.
  - Integrated `ScrollableDummyWidget` (a 100-item ListView.builder) into the example project control panel to visually demonstrate automatic scroll-chaining protection.

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