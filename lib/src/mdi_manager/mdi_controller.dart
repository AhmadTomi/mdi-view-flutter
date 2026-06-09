part of '../../mdi_view.dart';

// ── MdiController ─────────────────────────────────────────────────────────────


/// Top-level controller for the MDI surface.
///
/// Owns:
///   • The ordered window map (Z-order: last entry = topmost window).
///   • Scroll controllers for the MDI canvas.
///   • The [MdiTabController] for the tab strip.
///   • Maximise state.
///
/// Does **not** own [ResizeableWindowController] instances beyond lifecycle
/// management — they self-manage geometry via callbacks wired in [addWindow].
class MdiController extends ChangeNotifier {
  // ── Window registry ───────────────────────────────────────────────────────

  /// LinkedHashMap preserves insertion / Z-order (last = topmost).
  final Map<String, ResizeableWindowController> _windows = {};

  List<ResizeableWindowController> get windows =>
      List.unmodifiable(_windows.values);

  // ── Window-change stream ──────────────────────────────────────────────────

  final _windowChangeStream = StreamController<String>.broadcast();

  /// Emits the [tag] of a window whenever it is added, removed, or its
  /// argument/position changes.
  Stream<String> get onWindowChange => _windowChangeStream.stream;

  // ── Layout ────────────────────────────────────────────────────────────────

  /// Visible area of the MDI host (updated by [MdiManager] on layout changes).
  Size screenSize = Size.zero;

  /// Total canvas size (≥ [screenSize]; expands to fit window bounds).
  Size mdiSize = Size.zero;

  // ── State ─────────────────────────────────────────────────────────────────

  bool isMaximize = false;
  bool hasFocus = false;

  // ── Scroll controllers ────────────────────────────────────────────────────

  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();

  /// Shadow scroll controller that drives the right-side scrollbar thumb
  /// without conflicting with the primary [verticalController].
  final ScrollController verticalScrollBarController = ScrollController();

  // ── Sub-controllers ───────────────────────────────────────────────────────

  final MdiTabController tabMenuController = MdiTabController();

  // ── Private helpers ───────────────────────────────────────────────────────

  final _Debouncer _debouncer = _Debouncer(milliseconds: 100);
  void Function(String tag)? _onCloseCallback;

  // ── Convenience getters ───────────────────────────────────────────────────

  ResizeableWindowController? get frontWindow =>
      _windows.isNotEmpty ? _windows.values.last : null;

  ResizeableWindowController? getWindow(String tag) => _windows[tag];
  bool isWindowExist(String tag) => _windows.containsKey(tag);
  bool isFrontWindow(String tag) => frontWindow?.tag == tag;

  Map<String, ParameterWindow> get parameterWindowsMap =>
      _windows.map((k, v) => MapEntry(k, v.parameterWindow));

  List<ParameterWindow> get parameterWindows =>
      _windows.values.map((e) => e.parameterWindow).toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Must be called once after the widget tree has been attached.
  ///
  /// [onClose] — optional callback invoked after a window is removed.
  void init([void Function(String tag)? onClose]) {
    _onCloseCallback = onClose;
    _syncScrollBars();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabMenuController.init();
      requestLastWindowFocus();
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _windowChangeStream.close();
    tabMenuController.dispose();
    horizontalController.dispose();
    verticalController.dispose();
    verticalScrollBarController.dispose();

    for (final c in _windows.values) {
      c.dispose();
    }
    _windows.clear();
    super.dispose();
  }

  // ── Keyboard handler ──────────────────────────────────────────────────────

  /// Returns `true` if the event was consumed.
  bool onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    if (!HardwareKeyboard.instance.isAltPressed) return false;

    final key = event.logicalKey;

    if (HardwareKeyboard.instance.isShiftPressed) {
      // Ctrl+Alt+Shift+Arrow → move front window by grid step.
      final w = frontWindow;
      if (w == null) return false;

      // Fix: Execute the move method, then return true on the next line.
      if (key == LogicalKeyboardKey.arrowRight) {
        w.moveRight();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        w.moveLeft();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        w.moveUp();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        w.moveDown();
        return true;
      }

      return false;
    }

    // Ctrl+Alt+Arrow → cycle focus.
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      moveFocusNext();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      moveFocusPrevious();
      return true;
    }

    return false;
  }

  // ── Window management ─────────────────────────────────────────────────────

  /// Creates and registers a new window.
  ///
  /// Throws [StateError] if [parameter.tag] is already in use.
  ResizeableWindowController addWindow({
    required ParameterWindow parameter,
    required Widget Function(ResizeableWindowController) child,
    bool notify = true,
  }) {
    final tag = parameter.tag;
    if (_windows.containsKey(tag)) {
      throw StateError('MDI window tag "$tag" already exists.');
    }

    // Auto-centre when position is unset.
    if (parameter.isPositionUnset) {
      final jitter = Random().nextInt(60) - 30; // ±30 px so windows cascade
      parameter = parameter.withPosition(
        posX: max(0.0, (screenSize.width - parameter.currentWidth) / 2) + jitter,
        posY: max(0.0, (screenSize.height - parameter.currentHeight) / 2) + jitter,
      );
    }

    final ctrl = ResizeableWindowController(parameter: parameter, child: child);

    ctrl.initAction(
      onClose: (t) => removeWindow(t, requestFocusToPrevious: true),
      toggleMaximize: (action) {
        isMaximize = !isMaximize;
        action(screenSize);
        _recalculateMdiSize();
        notifyListeners();
        _debouncer.run(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollTo(ctrl.x, ctrl.y, animate: !isMaximize);
          });
        });
      },
      onFocusChange: (focused) {
        if (ctrl.isDisposed) return;
        _onWindowFocusChanged(focused, ctrl);
        if (focused) tabMenuController.notifyListeners();
      },
      onPositionChange: (_, __) {
        _debouncer.run(() {
          final changed = _recalculateMdiSize();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isMaximize) scrollTo(ctrl.xBound, ctrl.yBound);
          });
          if (changed) notifyListeners();
          _emitWindowChange(ctrl.tag);
        });
      },
      onArgumentUpdate: (_) => _emitWindowChange(ctrl.tag),
    );

    if (isMaximize) ctrl.toggleMaximize(screenSize, true);

    _registerWindow(tag, ctrl);

    // Delay notification slightly so the widget tree can mount the new window
    // before focus is requested.
    if (notify) {
      Future.delayed(const Duration(milliseconds: 100), notifyListeners);
    }

    return ctrl;
  }

  Future<String> removeWindow(
    String tag, {
    bool requestFocusToPrevious = false,
  }) async {
    if (tag.isEmpty) return '';

    if (requestFocusToPrevious && _windows.length >= 2) {
      final prev = _windows.values.elementAt(_windows.length - 2);
      WidgetsBinding.instance.addPostFrameCallback((_) => prev.requestFocus());
    }

    _unregisterWindow(tag);
    _recalculateMdiSize();
    notifyListeners();
    _onCloseCallback?.call(tag);
    return tag;
  }

  Future<String> removeFrontWindow() =>
      removeWindow(frontWindow?.tag ?? '', requestFocusToPrevious: true);

  void removeAllWindows() {
    final tags = _windows.keys.toList(growable: false);
    for (final t in tags) {
      _unregisterWindow(t);
    }
    _recalculateMdiSize();
    notifyListeners();
  }

  // ── Z-order / focus ───────────────────────────────────────────────────────

  void requestLastWindowFocus() => frontWindow?.requestFocus();

  void moveFocusNext() => _shiftFocus(1);

  void moveFocusPrevious() => _shiftFocus(-1);

  /// Brings [tag] to the front of the Z-order, optionally maximising it and
  /// requesting focus.
  void bringToFront(String tag, {bool maximize = false, bool focus = false}) {
    if (!_windows.containsKey(tag)) return;
    if (_windows.keys.last == tag && !maximize && !focus) return;

    final ctrl = _windows.remove(tag)!;
    _windows[tag] = ctrl;

    ctrl.toggleMaximize(screenSize, maximize);
    if (!isMaximize) scrollTo(ctrl.x, ctrl.y);

    notifyListeners();

    if (focus) ctrl.requestFocus();
  }

  void toggleMaximize() {
    isMaximize = !isMaximize;
    frontWindow?.toggleMaximize(screenSize, isMaximize);
    notifyListeners();
  }

  void onFocusChange(bool value) {
    hasFocus = value;
  }

  // ── Canvas size ───────────────────────────────────────────────────────────

  /// Returns `true` when [mdiSize] changed.
  bool _recalculateMdiSize() {
    double maxX = 0;
    double maxY = 0;
    for (final c in _windows.values) {
      if (c.x + c.currentWidth > maxX) maxX = c.x + c.currentWidth;
      if (c.y + c.currentHeight > maxY) maxY = c.y + c.currentHeight;
    }

    final newSize = Size(
      maxX.clamp(screenSize.width, double.infinity),
      maxY.clamp(screenSize.height, double.infinity),
    );

    if (newSize == mdiSize) return false;
    mdiSize = newSize;
    return true;
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  Future<void> scrollTo(double x, double y, {bool animate = true}) async {
    if (!horizontalController.hasClients || !verticalController.hasClients) {
      return;
    }

    final posH = horizontalController.position;
    final posV = verticalController.position;

    final visibleLeft = posH.pixels;
    final visibleTop = posV.pixels;
    final visibleRight = visibleLeft + screenSize.width;
    final visibleBottom = visibleTop + screenSize.height;

    double? targetX;
    double? targetY;

    if (x < visibleLeft) {
      targetX = x;
    } else if (x > visibleRight) {
      targetX = x - screenSize.width + ParameterWindow.defaultMinWidth;
    }

    if (y < visibleTop) {
      targetY = y;
    } else if (y > visibleBottom) {
      targetY = y - screenSize.height + ParameterWindow.defaultMinHeight;
    }

    // Local helper to handle the Future<void> compilation fix and DRY principle
    Future<void> executeScroll(ScrollController controller, double? target, ScrollPosition pos) {
      if (target == null) return Future.value();

      final clamped = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);

      if (animate) {
        return controller.animateTo(
          clamped,
          duration: _scrollDuration(controller, clamped),
          curve: Curves.easeInOut,
        );
      } else {
        // Safely execute the synchronous method, then return an empty Future
        controller.jumpTo(clamped);
        return Future.value();
      }
    }

    // Execute both axes concurrently
    await Future.wait([
      executeScroll(horizontalController, targetX, posH),
      executeScroll(verticalController, targetY, posV),
    ]);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _registerWindow(String tag, ResizeableWindowController ctrl) {
    _windows[tag] = ctrl;
    tabMenuController.addTab(tag, ctrl);
    _emitWindowChange(ctrl.tag);
  }

  void _unregisterWindow(String tag) {
    final ctrl = _windows.remove(tag);
    if (ctrl == null) return;
    tabMenuController.removeTab(tag);
    _emitWindowChange(ctrl.tag);
    ctrl.dispose();
  }

  void _emitWindowChange(String tag) {
    if (!_windowChangeStream.isClosed) {
      _windowChangeStream.add(tag);
    }
  }

  void _onWindowFocusChanged(
    bool focused,
    ResizeableWindowController ctrl,
  ) {
    if (!focused) return;

    final alreadyFront = frontWindow == ctrl;

    if (!alreadyFront) {
      final oldFront = frontWindow;

      // Promote to top of Z-order.
      _windows.remove(ctrl.tag);
      _windows[ctrl.tag] = ctrl;

      if (isMaximize) {
        ctrl.toggleMaximize(screenSize, true);
      } else {
        scrollTo(ctrl.x, ctrl.y);
      }

      notifyListeners();

      // Unmaximise the window that was previously on top.
      if (oldFront != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldFront.toggleMaximize(screenSize, false);
        });
      }
    } else if (hasFocus) {
      ctrl.toggleMaximize(screenSize, isMaximize);
    }
  }

  void _shiftFocus(int direction) {
    if (_windows.length < 2) return;
    final tabs = tabMenuController.tabControllers;
    final current = tabs.indexWhere((c) => c.tag == frontWindow?.tag);
    if (current == -1) return;
    final next = (current + direction).clamp(0, tabs.length - 1);
    final wrapped =
        (current + direction + tabs.length) % tabs.length;
    // Use wrapped index so navigation cycles through all tabs.
    tabs[wrapped].requestFocus();
  }

  void _syncScrollBars() {
    verticalController.addListener(() {
      if (verticalScrollBarController.hasClients &&
          !verticalScrollBarController.position.isScrollingNotifier.value) {
        verticalScrollBarController
            .jumpTo(verticalController.position.pixels);
      }
    });

    verticalScrollBarController.addListener(() {
      if (verticalController.hasClients &&
          !verticalController.position.isScrollingNotifier.value) {
        verticalController
            .jumpTo(verticalScrollBarController.position.pixels);
      }
    });
  }

  Duration _scrollDuration(ScrollController sc, double target) {
    const double speed = 0.5;
    const int minMs = 200;
    const int maxMs = 300;
    final distance = (target - sc.position.pixels).abs();
    return Duration(
      milliseconds: (distance * speed).toInt().clamp(minMs, maxMs),
    );
  }
}

// ── _Debouncer ────────────────────────────────────────────────────────────────

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() => _timer?.cancel();
}

// ── Tiny extension ────────────────────────────────────────────────────────────

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
