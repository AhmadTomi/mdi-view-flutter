part of '../../mdi_view.dart';

// ── Callback typedefs ─────────────────────────────────────────────────────────

typedef _ScreenAction = void Function(void Function(Size screenSize) action);
typedef _PositionChangeCallback = void Function(Size position, Size size);
typedef _ArgumentUpdateCallback = void Function(Map<String, dynamic> argument);

// ── Controller ────────────────────────────────────────────────────────────────

/// Manages the runtime state (position, size, focus, maximization) for a
/// single MDI window.
///
/// Separation of concerns:
///   • All geometry mutation lives here, not in the widget.
///   • Callbacks decouple this controller from [MdiController] — the parent
///     wires them up via [initAction]; this class has no import dependency on it.
///   • [ParameterWindow] stays a pure value object; this class owns the
///     mutable counterpart fields (x, y, currentWidth, currentHeight).
class ResizeableWindowController extends ChangeNotifier {
  // ── Focus ─────────────────────────────────────────────────────────────────

  final FocusScopeNode focusScopeNode;

  // ── Content builder ───────────────────────────────────────────────────────

  /// Called once and cached in [ResizableWindowState] — must be stable
  /// across rebuilds (identity equality respected by [AnimatedBuilder]).
  final Widget Function(ResizeableWindowController controller) child;

  // ── Geometry ──────────────────────────────────────────────────────────────

  double x;
  double y;
  double currentWidth;
  double currentHeight;

  // ── Pixel-snapped render geometry ─────────────────────────────────────────

  /// Whole-pixel readings of [x], [y], [currentWidth], and [currentHeight]
  /// for **rendering only**.
  ///
  /// Pointer deltas — especially from macOS trackpads, which routinely
  /// report fractional sub-pixel movement — accumulate into the raw
  /// geometry fields as long decimal doubles while dragging or resizing.
  /// Painting those fractional values directly produces blurry or
  /// doubled-up border lines, most visible on macOS displays where the
  /// logical-to-device pixel ratio isn't a clean 2x (e.g. a non-Retina
  /// external monitor).
  ///
  /// The underlying fields stay full precision so drag math, grid
  /// snapping, and persisted geometry (`parameterWindow`) remain accurate —
  /// only the widgets that actually paint a frame should read these.
  double get renderX => x.roundToDouble();
  double get renderY => y.roundToDouble();
  double get renderWidth => currentWidth.roundToDouble();
  double get renderHeight => currentHeight.roundToDouble();

  // ── State flags ───────────────────────────────────────────────────────────

  bool isMaximized = false;

  /// Snapshot of size before maximisation (restored on un-maximize).
  Size _preMaximizeSize = Size.zero;

  /// Snapshot of position before maximisation.
  Size _preMaximizePosition = Size.zero;

  /// Last known screen size — updated by [MdiManager] on layout changes.
  Size screenSize = Size.zero;

  // ── Snap behaviour ────────────────────────────────────────────────────────

  final double snapRange;
  final double widgetPadding;

  // ── Callbacks (wired by MdiController.initAction) ─────────────────────────

  void Function(bool hasFocus)? onFocusChange;
  void Function(String tag)? _onClose;
  _ScreenAction? _toggleMaximize;
  _PositionChangeCallback? _onPositionChange;
  _ArgumentUpdateCallback? _onArgumentUpdate;
  void Function()? _onBringToFront;
  void Function(PointerDownEvent event)? _onStartDrag;
  void Function(PointerDownEvent event, {EdgeSide? side, CornerSide? corner})? _onStartResize;
  void Function(bool isHovering)? _onHoverChange;
  void Function(PointerScrollEvent event)? _onWorkspacePointerScroll;

  void Function(PointerScrollEvent event)? get onWorkspacePointerScroll =>
      _onWorkspacePointerScroll;

  // ── Hover state ───────────────────────────────────────────────────────────

  bool _isHovered = false;
  final ValueNotifier<bool> hoverNotifier = ValueNotifier<bool>(false);

  // ── Private ───────────────────────────────────────────────────────────────

  final ParameterWindow _parameter;
  Map<String, dynamic> _argument;

  bool _isDisposed = false;

  // Pan-drag state for GestureDetector-based header dragging
  Offset? _panDragStart;
  Offset? _panPointerStart;

  // Contexts that register to ignore dragging inside their bounds
  final Set<BuildContext> _ignoreDragContexts = {};

  void registerIgnoreDragContext(BuildContext context) {
    _ignoreDragContexts.add(context);
  }

  void unregisterIgnoreDragContext(BuildContext context) {
    _ignoreDragContexts.remove(context);
  }

  bool _shouldIgnoreDrag(Offset globalPosition) {
    // 1. Check explicitly ignored contexts (IgnoreWindowDrag)
    if (_ignoreDragContexts.isNotEmpty) {
      for (final context in _ignoreDragContexts) {
        if (!context.mounted) continue;
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) continue;
        try {
          final localPos = renderBox.globalToLocal(globalPosition);
          final bounds = Rect.fromLTWH(0, 0, renderBox.size.width, renderBox.size.height);
          if (bounds.contains(localPos)) {
            return true;
          }
        } catch (_) {
          // Safe-guard in case coordinate conversion fails
        }
      }
    }

    // 2. Perform automatic hit-testing for viewports, platform views (like InAppWebView), editable fields, and interactive controls
    final windowContext = GlobalObjectKey(this).currentContext;
    if (windowContext == null || !windowContext.mounted) return false;
    final windowRenderBox = windowContext.findRenderObject() as RenderBox?;
    if (windowRenderBox == null || !windowRenderBox.hasSize) return false;

    MdiStyleConfiguration? style;
    try {
      style = MdiStyleProvider.of(windowContext);
    } catch (_) {
      // Safe-guard in case context lookup fails
    }

    try {
      final localPos = windowRenderBox.globalToLocal(globalPosition);
      final BoxHitTestResult hitTestResult = BoxHitTestResult();
      windowRenderBox.hitTest(hitTestResult, position: localPos);

      for (final entry in hitTestResult.path) {
        final target = entry.target;

        // Custom style predicate override
        if (style?.shouldIgnoreDragTarget?.call(target) == true) {
          return true;
        }

        final typeStr = target.runtimeType.toString();

        // 2a. Viewports, platform views, editable fields, and standard/custom sliders & controls by type name
        if (target is RenderAbstractViewport ||
            typeStr.contains('Viewport') ||
            typeStr.contains('PlatformView') ||
            typeStr.contains('RenderEditable') ||
            typeStr == '_RenderDecoration' ||
            typeStr.contains('Slider') ||
            typeStr.contains('RangeSlider') ||
            typeStr.contains('Thumb') ||
            typeStr.contains('Track') ||
            typeStr.contains('Scrollbar') ||
            typeStr.contains('Knob')) {
          return true;
        }

        // 2b. Semantic gesture handlers with active horizontal/vertical drag updates
        if (target is RenderSemanticsGestureHandler) {
          if (target.onHorizontalDragUpdate != null ||
              target.onVerticalDragUpdate != null) {
            return true;
          }
        }

        // 2c. Pointer listeners with pointer movement tracking (excluding window itself)
        if (target is RenderPointerListener && target != windowRenderBox) {
          if (target.onPointerMove != null ||
              target.onPointerPanZoomUpdate != null) {
            return true;
          }
        }
      }
    } catch (_) {
      // Safe-guard in case coordinate conversions or hit-testing throws
    }

    return false;
  }

  // ── Constructor ───────────────────────────────────────────────────────────

  ResizeableWindowController({
    required ParameterWindow parameter,
    double? snapRange,
    required this.child,
  })  : snapRange = snapRange ?? 30.0,
        widgetPadding = 0.0,
        _parameter = parameter,
        _argument = Map<String, dynamic>.of(parameter.argument),
        focusScopeNode = FocusScopeNode(),
        x = parameter.x,
        y = parameter.y,
        currentWidth = parameter.currentWidth,
        currentHeight = parameter.currentHeight;

  late final Widget widget = ResizableWindow(
    key: GlobalObjectKey(this),
    controller: this,
  );

  // ── Public interface ──────────────────────────────────────────────────────
  
  bool get isDisposed => _isDisposed;
  bool get hasFocus => focusScopeNode.hasFocus;
  bool get isHovered => _isHovered;
  bool get isHovering => _isHovered;

  String get tag => _parameter.tag;
  String get title => _parameter.title;

  double get xBound => x + currentWidth;
  double get yBound => y + currentHeight;

  double get minWidth => _parameter.minWidth;
  double get minHeight => _parameter.minHeight;

  Map<String, dynamic> get argument => Map.unmodifiable(_argument);

  /// Translation offset applied during active dragging to achieve 120 FPS
  /// GPU layer compositing without triggering continuous layout passes.
  final ValueNotifier<Offset> dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);

  double get visualX => x + dragOffsetNotifier.value.dx;
  double get visualY => y + dragOffsetNotifier.value.dy;

  /// Snapshot of the current mutable state as an immutable [ParameterWindow].
  ParameterWindow get parameterWindow => _parameter.copyWith(
    x: x,
    y: y,
    currentHeight: currentHeight,
    currentWidth: currentWidth,
    argument: _argument,
  );

  /// Optional key-event handler installed by the content widget.
  bool Function(KeyEvent event)? onKeyEvent;

  /// Optional hover-change handler installed by the content widget.
  void Function(bool isHovered)? onHover;

  /// Callback that returns a list of other active windows' coordinates for snapping.
  List<Rect> Function()? getOtherWindowRects;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void initAction({
    void Function(bool hasFocus)? onFocusChange,
    void Function(String tag)? onClose,
    _ScreenAction? toggleMaximize,
    _PositionChangeCallback? onPositionChange,
    _ArgumentUpdateCallback? onArgumentUpdate,
    void Function()? onBringToFront,
    void Function(PointerDownEvent event)? onStartDrag,
    void Function(PointerDownEvent event, {EdgeSide? side, CornerSide? corner})? onStartResize,
    void Function(bool isHovering)? onHoverChange,
    void Function(PointerScrollEvent event)? onWorkspacePointerScroll,
  }) {
    this.onFocusChange = onFocusChange;
    _onClose = onClose;
    _toggleMaximize = toggleMaximize;
    _onPositionChange = onPositionChange;
    _onArgumentUpdate = onArgumentUpdate;
    _onBringToFront = onBringToFront;
    _onStartDrag = onStartDrag;
    _onStartResize = onStartResize;
    _onHoverChange = onHoverChange;
    _onWorkspacePointerScroll = onWorkspacePointerScroll;
  }

  /// Evaluates whether a pointer event at [globalPosition] should bypass window
  /// dragging / workspace scrolling because it is over an interactive child widget
  /// (e.g. TextField, ListView, Slider, custom gesture handlers).
  bool shouldIgnoreDrag(Offset globalPosition) => _shouldIgnoreDrag(globalPosition);

  @override
  void dispose() {
    assert(!_isDisposed, 'dispose() called twice on $runtimeType($tag)');
    _isDisposed = true;
    focusScopeNode.dispose();
    hoverNotifier.dispose();
    dragOffsetNotifier.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void close() => _onClose?.call(_parameter.tag);

  void requestFocus() {
    if (!focusScopeNode.hasFocus) {
      focusScopeNode.requestScopeFocus();
    }
  }

  void bringToFront() {
    requestFocus();
    _onBringToFront?.call();
  }

  void setHover(bool isHovering) {
    if (_isHovered == isHovering) return;
    _isHovered = isHovering;
    hoverNotifier.value = isHovering;
    notifyListeners();
    onHover?.call(isHovering);
    _onHoverChange?.call(isHovering);
  }

  void startDrag(PointerDownEvent event) {
    if (_shouldIgnoreDrag(event.position)) return;
    requestFocus();
    _onStartDrag?.call(event);
  }

  void startResize(PointerDownEvent event, {EdgeSide? side, CornerSide? corner}) =>
      _onStartResize?.call(event, side: side, corner: corner);

  void updatePosition(double x, double y) {
    this.x = x;
    this.y = y;
    notifyListeners();
  }

  void updateGeometry({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    this.x = x;
    this.y = y;
    currentWidth = width;
    currentHeight = height;
    notifyListeners();
  }

  /// Fires after any drag/resize that should persist the new geometry.
  void positionChangeAction() {
    _onPositionChange?.call(Size(x, y), Size(currentWidth, currentHeight));
  }

  void setArgument(Map<String, dynamic> updates) {
    _argument = {..._argument, ...updates};
    _onArgumentUpdate?.call(_argument);
  }

  void updateParameter({
    required double x,
    required double y,
    required double currentHeight,
    required double currentWidth,
  }) {
    this.x = x;
    this.y = y;
    this.currentHeight = currentHeight;
    this.currentWidth = currentWidth;
    notifyListeners();
    positionChangeAction();
  }

  // ── Maximize / restore ────────────────────────────────────────────────────

  /// Toggles or forces the maximised state.
  ///
  /// [isMaximize] — `null` means toggle, `true`/`false` forces the state.
  void toggleMaximize(Size screen, [bool? isMaximize]) {
    final targetState = isMaximize ?? !isMaximized;
    if (targetState == isMaximized) return;

    if (targetState) {
      // Save current geometry then expand to fill screen.
      _preMaximizePosition = Size(x, y);
      _preMaximizeSize = Size(currentWidth, currentHeight);
      x = 0;
      y = 0;
      currentWidth = screen.width;
      currentHeight = screen.height;
    } else {
      // Restore saved geometry.
      x = _preMaximizePosition.width;
      y = _preMaximizePosition.height;
      currentWidth = _preMaximizeSize.width;
      currentHeight = _preMaximizeSize.height;
    }

    isMaximized = targetState;
    notifyListeners();
  }

  // ── Keyboard window positioning ───────────────────────────────────────────

  void moveLeft() {
    if (isMaximized) return;
    x = max(0.0, _snap(x - ParameterWindow.defaultWidth, ParameterWindow.defaultWidth));
    y = max(0.0, _snap(y, ParameterWindow.defaultMinHeight));
    notifyListeners();
    positionChangeAction();
  }

  void moveRight() {
    if (isMaximized) return;
    x = max(0.0, _snap(x + ParameterWindow.defaultWidth, ParameterWindow.defaultWidth));
    y = max(0.0, _snap(y, ParameterWindow.defaultMinHeight));
    notifyListeners();
    positionChangeAction();
  }

  void moveUp() {
    if (isMaximized) return;
    y = max(0.0, _snap(y - ParameterWindow.defaultMinHeight, ParameterWindow.defaultMinHeight));
    x = max(0.0, _snap(x, ParameterWindow.defaultWidth));
    notifyListeners();
    positionChangeAction();
  }

  void moveDown() {
    if (isMaximized) return;
    y = max(0.0, _snap(y + ParameterWindow.defaultMinHeight, ParameterWindow.defaultMinHeight));
    x = max(0.0, _snap(x, ParameterWindow.defaultWidth));
    notifyListeners();
    positionChangeAction();
  }

  // ── Drag: move window ─────────────────────────────────────────────────────

  /// Returns a widget that handles dragging the window and optionally
  /// double-tapping to toggle maximise.
  ///
  /// When [canDoubleClick] is true, uses [GestureDetector] with both
  /// [onDoubleTap] and pan callbacks so the gesture arena properly
  /// distinguishes double-taps from drags — matching the pattern used
  /// by [_TapTarget] in `mdi_tab_widget.dart`.
  Widget dragWidget({
    required Widget child,
    bool canDoubleClick = true,
    bool useGestureDetector = false,
  }) {
    if (canDoubleClick || useGestureDetector) {
      return GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.translucent,
        onDoubleTap: canDoubleClick
            ? () {
                _toggleMaximize?.call((s) => toggleMaximize(s));
              }
            : null,
        onPanStart: (details) {
          if (isMaximized) return;
          if (_shouldIgnoreDrag(details.globalPosition)) return;
          requestFocus();
          bringToFront();
          // Store drag origin so onPanUpdate can compute deltas.
          _panDragStart = Offset(x, y);
          _panPointerStart = details.globalPosition;
          dragOffsetNotifier.value = Offset.zero;
        },
        onPanUpdate: (details) {
          if (isMaximized || _panDragStart == null) return;
          final delta = details.globalPosition - _panPointerStart!;
          x = (_panDragStart!.dx + delta.dx).clamp(0.0, double.infinity);
          y = (_panDragStart!.dy + delta.dy).clamp(0.0, double.infinity);
          notifyListeners();
        },
        onPanEnd: (details) {
          _panDragStart = null;
          _panPointerStart = null;
          dragOffsetNotifier.value = Offset.zero;
          if (!isMaximized) {
            snapWindowPosition();
            positionChangeAction();
          }
          notifyListeners();
        },
        onPanCancel: () {
          _panDragStart = null;
          _panPointerStart = null;
          dragOffsetNotifier.value = Offset.zero;
          notifyListeners();
        },
        child: child,
      );
    }

    // No double-click: use raw Listener for immediate drag via canvas-level
    // pointer tracking (e.g. for body drag and unfocus blocker).
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          startDrag(event);
        }
      },
      child: child,
    );
  }

  // ── Drag-end snap helpers ─────────────────────────────────────────────────

  void snapWindowPosition() {
    final snappedToEdge = _snapToNearestEdges();
    if (!snappedToEdge) {
      final snapped = _snapSize(
        Size(x, y),
        Size(ParameterWindow.defaultWidth, ParameterWindow.defaultMinHeight),
      );
      if (snapped != null) {
        x = snapped.width;
        y = snapped.height;
        notifyListeners();
      }
    }
  }

  void onVerticalDragBottomEnd(DragEndDetails _) {
    final didSnap = _snapBottomEdgeToOtherWindows();
    if (!didSnap) {
      _trySnapHeight(preserveBottom: false);
    }
  }

  void onVerticalDragTopEnd(DragEndDetails _) {
    final didSnap = _snapTopEdgeToOtherWindows();
    if (!didSnap) {
      _trySnapHeight(preserveBottom: true);
    }
  }

  void onHorizontalRightDragEnd(DragEndDetails _) {
    final didSnap = _snapRightEdgeToOtherWindows();
    if (!didSnap) {
      _trySnapWidth(preserveRight: false);
    }
  }

  void onHorizontalLeftDragEnd(DragEndDetails _) {
    final didSnap = _snapLeftEdgeToOtherWindows();
    if (!didSnap) {
      _trySnapWidth(preserveRight: true);
    }
  }

  // ── Edge snapping helpers ──────────────────────────────────────────────────

  bool _snapToNearestEdges() {
    if (isMaximized || getOtherWindowRects == null) return false;
    final otherRects = getOtherWindowRects!();
    const double threshold = 12.0;

    double? snappedX;
    double? snappedY;

    final myLeft = x;
    final myRight = x + currentWidth;
    final myTop = y;
    final myBottom = y + currentHeight;

    // Canvas boundary snap (0, 0)
    if (myLeft.abs() < threshold) {
      snappedX = 0;
    }
    if (myTop.abs() < threshold) {
      snappedY = 0;
    }

    for (final rect in otherRects) {
      final oLeft = rect.left;
      final oRight = rect.right;
      final oTop = rect.top;
      final oBottom = rect.bottom;

      // X-axis alignment snap (snap left/right to other's left/right)
      if ((myLeft - oLeft).abs() < threshold) {
        snappedX = oLeft;
      } else if ((myLeft - oRight).abs() < threshold) {
        snappedX = oRight;
      } else if ((myRight - oLeft).abs() < threshold) {
        snappedX = oLeft - currentWidth;
      } else if ((myRight - oRight).abs() < threshold) {
        snappedX = oRight - currentWidth;
      }

      // Y-axis alignment snap (snap top/bottom to other's top/bottom)
      if ((myTop - oTop).abs() < threshold) {
        snappedY = oTop;
      } else if ((myTop - oBottom).abs() < threshold) {
        snappedY = oBottom;
      } else if ((myBottom - oTop).abs() < threshold) {
        snappedY = oTop - currentHeight;
      } else if ((myBottom - oBottom).abs() < threshold) {
        snappedY = oBottom - currentHeight;
      }
    }

    bool didSnap = false;
    if (snappedX != null) {
      x = snappedX;
      didSnap = true;
    }
    if (snappedY != null) {
      y = snappedY;
      didSnap = true;
    }

    if (didSnap) {
      notifyListeners();
    }
    return didSnap;
  }

  bool _snapRightEdgeToOtherWindows() {
    if (isMaximized || getOtherWindowRects == null) return false;
    final otherRects = getOtherWindowRects!();
    const double threshold = 12.0;

    final myRight = x + currentWidth;
    double? snappedRight;

    for (final rect in otherRects) {
      if ((myRight - rect.left).abs() < threshold) {
        snappedRight = rect.left;
      } else if ((myRight - rect.right).abs() < threshold) {
        snappedRight = rect.right;
      }
    }

    if (snappedRight != null) {
      final newW = snappedRight - x;
      if (newW >= _parameter.minWidth) {
        currentWidth = newW;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool _snapLeftEdgeToOtherWindows() {
    if (isMaximized || getOtherWindowRects == null) return false;
    final otherRects = getOtherWindowRects!();
    const double threshold = 12.0;

    final myLeft = x;
    double? snappedLeft;

    if (myLeft.abs() < threshold) {
      snappedLeft = 0;
    } else {
      for (final rect in otherRects) {
        if ((myLeft - rect.left).abs() < threshold) {
          snappedLeft = rect.left;
        } else if ((myLeft - rect.right).abs() < threshold) {
          snappedLeft = rect.right;
        }
      }
    }

    if (snappedLeft != null) {
      final rightPos = x + currentWidth;
      final newW = rightPos - snappedLeft;
      if (newW >= _parameter.minWidth && snappedLeft >= 0) {
        x = snappedLeft;
        currentWidth = newW;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool _snapBottomEdgeToOtherWindows() {
    if (isMaximized || getOtherWindowRects == null) return false;
    final otherRects = getOtherWindowRects!();
    const double threshold = 12.0;

    final myBottom = y + currentHeight;
    double? snappedBottom;

    for (final rect in otherRects) {
      if ((myBottom - rect.top).abs() < threshold) {
        snappedBottom = rect.top;
      } else if ((myBottom - rect.bottom).abs() < threshold) {
        snappedBottom = rect.bottom;
      }
    }

    if (snappedBottom != null) {
      final newH = snappedBottom - y;
      if (newH >= _parameter.minHeight) {
        currentHeight = newH;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool _snapTopEdgeToOtherWindows() {
    if (isMaximized || getOtherWindowRects == null) return false;
    final otherRects = getOtherWindowRects!();
    const double threshold = 12.0;

    final myTop = y;
    double? snappedTop;

    if (myTop.abs() < threshold) {
      snappedTop = 0;
    } else {
      for (final rect in otherRects) {
        if ((myTop - rect.top).abs() < threshold) {
          snappedTop = rect.top;
        } else if ((myTop - rect.bottom).abs() < threshold) {
          snappedTop = rect.bottom;
        }
      }
    }

    if (snappedTop != null) {
      final bottomPos = y + currentHeight;
      final newH = bottomPos - snappedTop;
      if (newH >= _parameter.minHeight && snappedTop >= 0) {
        y = snappedTop;
        currentHeight = newH;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  // ── Drag: resize edges ────────────────────────────────────────────────────

  void onHorizontalDragRight(DragUpdateDetails d) {
    currentWidth = (currentWidth + d.delta.dx).clamp(
      _parameter.minWidth,
      double.infinity,
    );
    notifyListeners();
  }

  void onHorizontalDragLeft(DragUpdateDetails d) {
    final rightPos = x + currentWidth;
    final newX = x + d.delta.dx;
    final newW = currentWidth - d.delta.dx;

    if (newW < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
      x = rightPos - currentWidth;
    } else if (newX <= 0) {
      x = 0;
      currentWidth = rightPos;
    } else {
      x = newX;
      currentWidth = newW;
    }
    notifyListeners();
  }

  void onHorizontalDragBottom(DragUpdateDetails d) {
    currentHeight = (currentHeight + d.delta.dy).clamp(
      _parameter.minHeight,
      double.infinity,
    );
    notifyListeners();
  }

  void onHorizontalDragTop(DragUpdateDetails d) {
    final bottomPos = y + currentHeight;
    final newY = y + d.delta.dy;
    final newH = currentHeight - d.delta.dy;

    if (newH < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
      y = bottomPos - currentHeight;
    } else if (newY <= 0) {
      y = 0;
      currentHeight = bottomPos;
    } else {
      y = newY;
      currentHeight = newH;
    }
    notifyListeners();
  }

  // ── Drag: resize corners ──────────────────────────────────────────────────

  void onHorizontalDragBottomRight(DragUpdateDetails d) {
    currentWidth = (currentWidth + d.delta.dx).clamp(
      _parameter.minWidth,
      double.infinity,
    );
    currentHeight = (currentHeight + d.delta.dy).clamp(
      _parameter.minHeight,
      double.infinity,
    );
    notifyListeners();
  }

  void onHorizontalDragBottomLeft(DragUpdateDetails d) {
    _resizeLeft(d.delta.dx);
    currentHeight = (currentHeight + d.delta.dy).clamp(
      _parameter.minHeight,
      double.infinity,
    );
    notifyListeners();
  }

  void onHorizontalDragTopRight(DragUpdateDetails d) {
    currentWidth = (currentWidth + d.delta.dx).clamp(
      _parameter.minWidth,
      double.infinity,
    );
    _resizeTop(d.delta.dy);
    notifyListeners();
  }

  void onHorizontalDragTopLeft(DragUpdateDetails d) {
    _resizeLeft(d.delta.dx);
    _resizeTop(d.delta.dy);
    notifyListeners();
  }

  // ── Private resize helpers ────────────────────────────────────────────────

  /// Resize from the left edge (moves x, adjusts width).
  void _resizeLeft(double dx) {
    final rightPos = x + currentWidth;
    final newX = x + dx;
    final newW = currentWidth - dx;

    if (newW < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
      x = rightPos - currentWidth;
    } else if (newX <= 0) {
      x = 0;
      currentWidth = rightPos;
    } else {
      x = newX;
      currentWidth = newW;
    }
  }

  /// Resize from the top edge (moves y, adjusts height).
  void _resizeTop(double dy) {
    final bottomPos = y + currentHeight;
    final newY = y + dy;
    final newH = currentHeight - dy;

    if (newH < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
      y = bottomPos - currentHeight;
    } else if (newY <= 0) {
      y = 0;
      currentHeight = bottomPos;
    } else {
      y = newY;
      currentHeight = newH;
    }
  }

  // ── Private snap helpers ──────────────────────────────────────────────────

  /// Returns the nearest multiple of [n] to [value].
  double _snap(double value, double n) {
    assert(n > 0);
    final lower = (value ~/ n) * n;
    final upper = lower + n;
    return (value - lower < upper - value) ? lower : upper;
  }

  /// Returns a snapped [Size] if the current value is within [snapRange] of
  /// a grid multiple, or `null` when no snap should occur.
  Size? _snapSize(Size current, Size grid) {
    final snapW = _snap(current.width, grid.width);
    final snapH = _snap(current.height, grid.height);

    bool inRange(double v, double t) =>
        (v - snapRange) < t && t < (v + snapRange);

    if (inRange(current.width, snapW) && inRange(current.height, snapH)) {
      return Size(snapW, snapH);
    }
    return null;
  }

  void _trySnapHeight({required bool preserveBottom}) {
    final snapped = _snap(currentHeight, ParameterWindow.defaultMinHeight);
    if ((currentHeight - snapped).abs() < snapRange) {
      if (preserveBottom) {
        final bottom = y + currentHeight;
        currentHeight = snapped;
        y = bottom - currentHeight;
      } else {
        currentHeight = snapped;
      }
      notifyListeners();
    }
  }

  void _trySnapWidth({required bool preserveRight}) {
    final snapped = _snap(currentWidth, ParameterWindow.defaultWidth);
    if ((currentWidth - snapped).abs() < snapRange) {
      if (preserveRight) {
        final right = x + currentWidth;
        currentWidth = snapped;
        x = right - currentWidth;
      } else {
        currentWidth = snapped;
      }
      notifyListeners();
    }
  }
}