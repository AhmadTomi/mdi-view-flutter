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

  // ── Private ───────────────────────────────────────────────────────────────

  final ParameterWindow _parameter;
  Map<String, dynamic> _argument;

  bool _isDisposed = false;

  // Double-tap detection state
  int _lastTapTimestamp = 0;
  int _consecutiveTaps = 1;

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

  // ── Public interface ──────────────────────────────────────────────────────

  bool get isDisposed => _isDisposed;
  bool get hasFocus => focusScopeNode.hasFocus;

  String get tag => _parameter.tag;
  String get title => _parameter.title;

  double get xBound => x + currentWidth;
  double get yBound => y + currentHeight;

  Map<String, dynamic> get argument => Map.unmodifiable(_argument);

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void initAction({
    void Function(bool hasFocus)? onFocusChange,
    void Function(String tag)? onClose,
    _ScreenAction? toggleMaximize,
    _PositionChangeCallback? onPositionChange,
    _ArgumentUpdateCallback? onArgumentUpdate,
  }) {
    this.onFocusChange = onFocusChange;
    _onClose = onClose;
    _toggleMaximize = toggleMaximize;
    _onPositionChange = onPositionChange;
    _onArgumentUpdate = onArgumentUpdate;
  }

  @override
  void dispose() {
    assert(!_isDisposed, 'dispose() called twice on $runtimeType($tag)');
    _isDisposed = true;
    focusScopeNode.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void close() => _onClose?.call(_parameter.tag);

  void requestFocus() {
    if (!focusScopeNode.hasFocus) {
      focusScopeNode.requestScopeFocus();
    }
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

  /// Returns a [GestureDetector] that handles dragging the window and
  /// optionally double-tapping to toggle maximise.
  Widget dragWidget({required Widget child, bool canDoubleClick = true}) {
    return GestureDetector(
      supportedDevices: const {PointerDeviceKind.mouse},
      onTap: () {
        requestFocus();
        if (!canDoubleClick) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastTapTimestamp < 300) {
          _consecutiveTaps++;
          if (_consecutiveTaps >= 2) {
            _toggleMaximize?.call((s) => toggleMaximize(s));
            _consecutiveTaps = 1;
          }
        } else {
          _consecutiveTaps = 1;
        }
        _lastTapTimestamp = now;
      },
      onPanStart: (_) {
        if (!isMaximized) requestFocus();
      },
      onPanUpdate: (details) {
        if (isMaximized) return;
        requestFocus();
        x = (x + details.delta.dx).clamp(0.0, double.infinity);
        y = (y + details.delta.dy).clamp(0.0, double.infinity);
        notifyListeners();
      },
      onPanEnd: (_) {
        if (isMaximized) return;
        _snapWindowPosition();
        positionChangeAction();
      },
      child: child,
    );
  }

  // ── Drag-end snap helpers ─────────────────────────────────────────────────

  void _snapWindowPosition() {
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

  void onVerticalDragBottomEnd(DragEndDetails _) =>
      _trySnapHeight(preserveBottom: false);

  void onVerticalDragTopEnd(DragEndDetails _) =>
      _trySnapHeight(preserveBottom: true);

  void onHorizontalRightDragEnd(DragEndDetails _) =>
      _trySnapWidth(preserveRight: false);

  void onHorizontalLeftDragEnd(DragEndDetails _) =>
      _trySnapWidth(preserveRight: true);

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