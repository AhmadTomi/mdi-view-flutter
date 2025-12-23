part of '../../mdi_view.dart';

class MdiController extends ChangeNotifier {
  // Uses LinkedHashMap to preserve insertion order (Z-order: last is top)
  final Map<String, ResizeableWindowController> _controllers = {};

  List<ResizeableWindowController> get windows => _controllers.values.toList();

  final _windowChangeStreamController = StreamController<String>.broadcast();
  Stream<String> get onWindowChange => _windowChangeStreamController.stream;

  Size screenSize = Size.zero;
  Size mdiSize = Size.zero;

  bool isMaximize = false;
  bool hasFocus = false;

  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();
  final ScrollController verticalScrollBarController = ScrollController();

  final MdiTabController tabMenuController = MdiTabController();

  final _debouncer = _Debouncer(milliseconds: 100);

  ResizeableWindowController? get frontWindow =>
      (_controllers.isNotEmpty) ? _controllers.values.last : null;

  ResizeableWindowController? getWindow(String tag) => _controllers[tag];
  bool isWindowExist(String tag) => _controllers.containsKey(tag);
  bool isFrontWindow(String tag) => frontWindow?.tag == tag;

  Map<String, ParameterWindow> get parameterWindowsMap =>
      _controllers.map((key, value) => MapEntry(key, value.parameterWindow));

  List<ParameterWindow> get parameterWindows =>
      _controllers.values.map((e) => e.parameterWindow).toList();

  void Function(String tag)? _onCloseCallback;

  void init([void Function(String tag)? onClose]) {
    verticalController.addListener(() {
      if (verticalScrollBarController.hasClients &&
          !verticalScrollBarController.position.isScrollingNotifier.value) {
        verticalScrollBarController.jumpTo(verticalController.position.pixels);
      }
    });
    verticalScrollBarController.addListener(() {
      if (verticalController.hasClients &&
          !verticalController.position.isScrollingNotifier.value) {
        verticalController.jumpTo(verticalScrollBarController.position.pixels);
      }
    });

    _onCloseCallback = onClose;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabMenuController.init();
      requestLastWindowFocus();
    });
  }

  @override
  void dispose() {
    horizontalController.dispose();
    verticalController.dispose();
    verticalScrollBarController.dispose();
    tabMenuController.dispose();
    _debouncer.dispose();

    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _windowChangeStreamController.close();
    super.dispose();
  }

  bool onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (HardwareKeyboard.instance.isControlPressed) {
        if (HardwareKeyboard.instance.isAltPressed) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            // CTRL + ALT + SHIFT + Arrow for move window Position
            final window = frontWindow;
            if (window != null) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                window.moveRight();
                return true;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                window.moveLeft();
                return true;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                window.moveUp();
                return true;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                window.moveDown();
                return true;
              }
            }
          }

          // CTRL + ALT + Arrow for move focus
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            moveFocusNext();
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            moveFocusPrevious();
            return true;
          }
        }
      }
    }
    return false;
  }

  void _addController(String tag, ResizeableWindowController controller) {
    _controllers[tag] = controller;
    tabMenuController.addTab(tag, controller);
    if (!_windowChangeStreamController.isClosed) {
      _windowChangeStreamController.add(controller.tag);
    }
  }

  void _removeController(String tag) {
    final controller = _controllers[tag];
    if (controller != null) {
      _controllers.remove(tag);
      tabMenuController.removeTab(tag);
      if (!_windowChangeStreamController.isClosed) {
        _windowChangeStreamController.add(controller.tag);
      }
      controller.dispose();
    }
  }

  ResizeableWindowController addWindow({
    required ParameterWindow parameter,
    required Widget Function(ResizeableWindowController controller) child,
    bool notify = true,
  }) {
    final tag = parameter.tag;
    if (_controllers.containsKey(tag)) {
      throw Exception('Tag $tag already exists');
    }

    if (parameter.x == -1 || parameter.y == -1) {
      // Centering Widget
      final double centerX =
          max(0, (screenSize.width - parameter.currentWidth) / 2) -
          (Random().nextInt(60) - 30);
      final double centerY =
          max(0, (screenSize.height - parameter.currentHeight) / 2) -
          (Random().nextInt(60) - 30);
      parameter.updateParameter(posX: centerX, posY: centerY);
    }

    final newController = ResizeableWindowController(
      parameter: parameter,
      child: child,
    );

    newController.initAction(
      onClose: (tag) => removeWindow(tag, true),
      toggleMaximize: (action) {
        isMaximize = !isMaximize;
        action(screenSize);
        calculateUpdateScreenSize();
        notifyListeners();
        _debouncer.run(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollTo(newController.x, newController.y, animate: !isMaximize);
          });
        });
      },
      onFocusChange: (hasFocus) {
        if (newController.isDisposed) return;
        _onWindowChangeFocus(hasFocus, newController);
      },
      onPositionChange: (position, size) {
        _debouncer.run(() {
          final needUpdate = calculateUpdateScreenSize();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isMaximize)
              scrollTo(newController.xBound, newController.yBound);
          });

          if (needUpdate) notifyListeners();
          if (!_windowChangeStreamController.isClosed) {
            _windowChangeStreamController.add(newController.tag);
          }
        });
      },
      onArgumentUpdate: (argument) {
        if (!_windowChangeStreamController.isClosed) {
          _windowChangeStreamController.add(newController.tag);
        }
      },
    );

    if (isMaximize) newController.toggleMaximize(screenSize, true);

    _addController(tag, newController);

    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      if (notify) notifyListeners();
    });

    return newController;
  }

  Future<String> removeWindow(String tag, [bool? requestFocus]) async {
    if (tag.isEmpty) return '';
    if (_controllers.length >= 2 && (requestFocus == true)) {
      final controller = _controllers.values.elementAt(
        (_controllers.length - 2),
      );
      controller.requestFocus();
    }
    _removeController(tag);
    calculateUpdateScreenSize();
    notifyListeners();
    _onCloseCallback?.call(tag);
    return tag;
  }

  Future<String> removeFrontWindow() {
    return removeWindow(frontWindow?.tag ?? '', true);
  }

  void removeAllWindows() {
    final tags = _controllers.keys.toList();
    for (var tag in tags) {
      _removeController(tag);
    }
    calculateUpdateScreenSize();
    notifyListeners();
  }

  bool calculateUpdateScreenSize() {
    var valuesX = _controllers.values.map((c) => c.x + c.currentWidth);
    var valuesY = _controllers.values.map((c) => c.y + c.currentHeight);

    double maxX = valuesX.fold(0.0, max);
    double maxY = valuesY.fold(0.0, max);

    final double newX = maxX.clamp(screenSize.width, double.infinity);
    final double newY = maxY.clamp(screenSize.height, double.infinity);

    final newMdiSize = Size(newX, newY);
    if (newMdiSize != mdiSize) {
      mdiSize = newMdiSize;
      return true;
    }
    return false;
  }

  void _onWindowChangeFocus(
    bool hasFocus,
    ResizeableWindowController controller,
  ) {
    if (!hasFocus) {
      return;
    }

    // Only update if the focused window is not already at the front
    final bool isChangingFrontWindow = frontWindow != controller;

    if (isChangingFrontWindow) {
      final oldFront = frontWindow;
      // Move to end (top)
      _controllers.remove(controller.tag);
      _controllers[controller.tag] = controller;

      if (isMaximize) {
        controller.toggleMaximize(screenSize, true);
      } else {
        scrollTo(controller.x, controller.y);
      }

      // Notify listeners to update the Z-order in the UI
      notifyListeners();

      // Handle maximization state for the old front window if needed
      if (oldFront != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldFront.toggleMaximize(screenSize, false);
        });
      }
    } else {
      if (this.hasFocus) {
        controller.toggleMaximize(screenSize, isMaximize);
      }
    }
  }

  void bringToFront(String tag, bool needMaximize, bool hasFocus) {
    if (_controllers.keys.last == tag) return;
    if (!_controllers.containsKey(tag)) return;

    final controller = _controllers.remove(tag);
    if (controller == null) return;
    _controllers[tag] = controller;

    controller.toggleMaximize(screenSize, needMaximize);

    if (!isMaximize) scrollTo(controller.x, controller.y);

    // Explicitly notify listeners to refresh Z-order
    notifyListeners();

    if (hasFocus) {
      controller.requestFocus();
    }
  }

  void requestLastWindowFocus() {
    if (_controllers.isEmpty) return;
    final controller = _controllers.values.last;
    controller.requestFocus();
  }

  void moveFocusNext() {
    if (_controllers.length < 2) return;
    final listTab = tabMenuController.tabControllers;
    final currentIndex = listTab.indexWhere(
      (element) => element.tag == frontWindow?.tag,
    );
    if (currentIndex == -1) return;
    int newIndex = currentIndex + 1;
    if (newIndex >= listTab.length) newIndex = 0;
    listTab[newIndex].requestFocus();
  }

  void moveFocusPrevious() {
    if (_controllers.length < 2) return;
    final listTab = tabMenuController.tabControllers;
    final currentIndex = listTab.indexWhere(
      (element) => element.tag == frontWindow?.tag,
    );
    if (currentIndex == -1) return;
    int newIndex = currentIndex - 1;
    if (newIndex < 0) newIndex = listTab.length - 1;
    listTab[newIndex].requestFocus();
  }

  Duration _calculateDuration(
    ScrollController scrollController,
    double targetPosition,
  ) {
    final distance = (targetPosition - scrollController.position.pixels).abs();
    const double speedMultiplier = 0.5;
    int maxDuration = 300;
    int minDuration = 200;
    return Duration(
      milliseconds: (distance * speedMultiplier).toInt().clamp(
        minDuration,
        maxDuration,
      ),
    );
  }

  Future<void> scrollTo(double x, double y, {bool animate = true}) async {
    // Get position objects
    final posH = horizontalController.position;
    final posV = verticalController.position;

    // Calculate the boundaries of the currently visible area
    final visibleLeft = posH.pixels;
    final visibleTop = posV.pixels;

    // Calculate the latest coordinate an item's top-left can be
    // and still be fully visible.
    final itemWidth = ParameterWindow.defaultMinWidth;
    final itemHeight = ParameterWindow.defaultMinHeight;
    final latestVisibleX = visibleLeft + screenSize.width;
    final latestVisibleY = visibleTop + screenSize.height;

    // --- REVISED LOGIC: Calculate correct targets ---

    // By default, the target is the current position (i.e., don't scroll)
    double targetX = visibleLeft;
    double targetY = visibleTop;
    bool needsHorizontalScroll = false;
    bool needsVerticalScroll = false;

    // Check horizontal
    if (x < visibleLeft) {
      // Item is off-screen to the LEFT. Scroll to align it with the left edge.
      targetX = x;
      needsHorizontalScroll = true;
    } else if (x > latestVisibleX) {
      // Item is off-screen to the RIGHT.
      // Scroll just enough to show it on the right edge.
      targetX = x - screenSize.width + itemWidth;
      needsHorizontalScroll = true;
    }

    // Check vertical
    if (y < visibleTop) {
      // Item is off-screen ABOVE. Scroll to align it with the top edge.
      targetY = y;
      needsVerticalScroll = true;
    } else if (y > latestVisibleY) {
      // Item is off-screen BELOW.
      // Scroll just enough to show it on the bottom edge.
      targetY = y - screenSize.height + itemHeight;
      needsVerticalScroll = true;
    }

    // Futures to hold our animation tasks
    Future<void> horizontalScroll = Future.value();
    Future<void> verticalScroll = Future.value();

    if (needsVerticalScroll) {
      // Clamp the *calculated* target
      final clampedTargetY = targetY.clamp(
        posV.minScrollExtent,
        posV.maxScrollExtent,
      );

      if (animate) {
        verticalScroll = verticalController.animateTo(
          clampedTargetY,
          duration: _calculateDuration(verticalController, clampedTargetY),
          curve: Curves.easeInOut,
        );
      } else {
        verticalController.jumpTo(clampedTargetY);
      }
    }

    if (needsHorizontalScroll) {
      // Clamp the *calculated* target
      if (animate) {
        final clampedTargetX = targetX.clamp(
          posH.minScrollExtent,
          posH.maxScrollExtent,
        );
        horizontalScroll = horizontalController.animateTo(
          clampedTargetX,
          duration: _calculateDuration(horizontalController, clampedTargetX),
          curve: Curves.easeInOut,
        );
      } else {
        horizontalController.jumpTo(targetX);
      }
    }

    // Run both animations at the same time
    await Future.wait([verticalScroll, horizontalScroll]);
  }

  void toggleMaximize() {
    isMaximize = !isMaximize;
    frontWindow?.toggleMaximize(screenSize, isMaximize);
    notifyListeners();
  }

  void onFocusChange(bool value) {
    if (hasFocus != value) {
      hasFocus = value;
    }
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    // If a timer is already active, cancel it
    if (_timer != null) {
      _timer!.cancel();
    }

    // Start a new timer
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
