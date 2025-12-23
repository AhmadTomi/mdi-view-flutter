part of '../../mdi_view.dart';

class ResizeableWindowController extends ChangeNotifier {
  final FocusScopeNode focusScopeNode;
  final Widget Function(ResizeableWindowController controller) child;

  // Callbacks
  void Function(bool hasFocus)? onFocusChange;
  void Function(String tag)? _onClose;
  void Function(Size position, Size size)? _onPositionChange;
  void Function(void Function(Size screenSize) action)? _toggleMaximize;
  void Function(Map<String, dynamic> argument)? _onArgumentUpdate;

  final ParameterWindow _parameter;

  ResizeableWindowController({
    required ParameterWindow parameter,
    double? snapRange,
    double? widgetPadding,
    required this.child,
  }) : snapRange = snapRange ?? 30,
       widgetPadding = 0.0,
       _parameter = parameter,
       focusScopeNode = FocusScopeNode() {
    x = parameter.x;
    y = parameter.y;
    currentHeight = parameter.currentHeight;
    currentWidth = parameter.currentWidth;
    _argument = parameter.argument;
  }

  void initAction({
    void Function(bool hasFocus)? onFocusChange,
    void Function(String tag)? onClose,
    void Function(void Function(Size screenSize))? toggleMaximize,
    void Function(Size position, Size size)? onPositionChange,
    void Function(Map<String, dynamic> argument)? onArgumentUpdate,
  }) {
    this.onFocusChange = onFocusChange;
    _onClose = onClose;
    _toggleMaximize = toggleMaximize;
    _onPositionChange = onPositionChange;
    _onArgumentUpdate = onArgumentUpdate;
  }

  double x = 0;
  double y = 0;
  double currentHeight = 400;
  double currentWidth = 400;
  Map<String, dynamic>? _argument;

  bool isMaximized = false;
  Size lastSize = const Size(0, 0);
  Size lastPosition = const Size(0, 0);
  Size screenSize = const Size(0, 0);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  bool get hasFocus => focusScopeNode.hasFocus;
  String get tag => _parameter.tag;
  String get title => _parameter.title;

  double get xBound => x + currentWidth;
  double get yBound => y + currentHeight;

  Map<String, dynamic>? get argument => _argument;

  late final double snapRange;
  late final double widgetPadding;

  ParameterWindow get parameterWindow => _parameter.copyWith(
    x: x,
    y: y,
    currentHeight: currentHeight,
    currentWidth: currentWidth,
    argument: _argument,
  );

  int _lastTap = 0;
  int _consecutiveTaps = 1;

  @override
  void dispose() {
    _isDisposed = true;
    focusScopeNode.dispose();
    super.dispose();
  }

  void close() {
    _onClose?.call(_parameter.tag);
  }

  void positionChangeAction() {
    _onPositionChange?.call(Size(x, y), Size(currentWidth, currentHeight));
  }

  void requestFocus() {
    if (focusScopeNode.hasFocus == false) {
      focusScopeNode.requestScopeFocus();
    }
  }

  void moveLeft() {
    if (isMaximized) return;
    x = max(
      0,
      _nearestMultiple(
        x - ParameterWindow.defaultWidth,
        ParameterWindow.defaultWidth,
      ),
    );
    y = max(0, _nearestMultiple(y, ParameterWindow.defaultMinHeight));
    notifyListeners();
    positionChangeAction();
  }

  void moveRight() {
    if (isMaximized) return;
    x = max(
      0,
      _nearestMultiple(
        x + ParameterWindow.defaultWidth,
        ParameterWindow.defaultWidth,
      ),
    );
    y = max(0, _nearestMultiple(y, ParameterWindow.defaultMinHeight));
    notifyListeners();
    positionChangeAction();
  }

  void moveUp() {
    if (isMaximized) return;
    y = max(
      0,
      _nearestMultiple(
        y - ParameterWindow.defaultMinHeight,
        ParameterWindow.defaultMinHeight,
      ),
    );
    x = max(0, _nearestMultiple(x, ParameterWindow.defaultWidth));
    notifyListeners();
    positionChangeAction();
  }

  void moveDown() {
    if (isMaximized) return;
    y = max(
      0,
      _nearestMultiple(
        y + ParameterWindow.defaultMinHeight,
        ParameterWindow.defaultMinHeight,
      ),
    );
    x = max(0, _nearestMultiple(x, ParameterWindow.defaultWidth));
    notifyListeners();
    positionChangeAction();
  }

  double _nearestMultiple(double number, double n) {
    double lowerMultiple = (number ~/ n) * n;
    double higherMultiple = lowerMultiple + n;
    return (number - lowerMultiple < higherMultiple - number)
        ? lowerMultiple
        : higherMultiple;
  }

  void setArgument(Map<String, dynamic> argument) {
    argument.forEach((key, value) {
      _argument?[key] = value;
    });
    _onArgumentUpdate?.call(_argument ?? {});
  }

  void updateParameter({
    required double x,
    required double y,
    required currentHeight,
    required currentWidth,
  }) {
    this.x = x;
    this.y = y;
    this.currentHeight = currentHeight;
    this.currentWidth = currentWidth;
    notifyListeners();
    positionChangeAction();
  }

  void checkSnap(Size current, Size snapN) {
    // calculate nearest snap area;
    final snapWidth = _nearestMultiple(current.width, snapN.width);
    final snapHeight = _nearestMultiple(current.height, snapN.height);

    // function to check condition
    bool isInRange(double value, double target) {
      return (value - snapRange) < target && target < (value + snapRange);
    }

    if (isInRange(current.width, snapWidth) &&
        isInRange(current.height, snapHeight)) {
      x = snapWidth;
      y = snapHeight;
      notifyListeners();
    }
  }

  void onWindowDragEnd() {
    final Size currentPosition = Size(x, y);
    Size defaultSnap = Size(
      ParameterWindow.defaultWidth,
      ParameterWindow.defaultHeight / 4,
    );
    checkSnap(currentPosition, defaultSnap);
    notifyListeners();
  }

  void onVerticalDragBottomEnd(DragEndDetails details) {
    double nearestSnap = _nearestMultiple(
      currentHeight,
      ParameterWindow.defaultHeight / 4,
    );
    if (currentHeight < (nearestSnap + snapRange) &&
        currentHeight > (nearestSnap - snapRange)) {
      currentHeight = nearestSnap;
      notifyListeners();
    }
  }

  void onVerticalDragTopEnd(DragEndDetails details) {
    double bottomPos = currentHeight + y;
    double nearestSnap = _nearestMultiple(
      currentHeight,
      ParameterWindow.defaultHeight / 4,
    );
    if (currentHeight < (nearestSnap + snapRange) &&
        currentHeight > (nearestSnap - snapRange)) {
      currentHeight = nearestSnap;
      y = bottomPos - currentHeight;
      notifyListeners();
    }
  }

  void onHorizontalLeftDragEnd(DragEndDetails details) {
    double rightPos = currentWidth + x;
    double nearestSnap = _nearestMultiple(
      currentWidth,
      ParameterWindow.defaultWidth,
    );
    if (currentWidth < (nearestSnap + snapRange) &&
        currentWidth > (nearestSnap - snapRange)) {
      currentWidth = nearestSnap;
      x = rightPos - currentWidth;
      notifyListeners();
    }
  }

  void onHorizontalRightDragEnd(DragEndDetails details) {
    double nearestSnap = _nearestMultiple(
      currentWidth,
      ParameterWindow.defaultWidth,
    );
    if (currentWidth < (nearestSnap + snapRange) &&
        currentWidth > (nearestSnap - snapRange)) {
      currentWidth = nearestSnap;
      notifyListeners();
    }
  }

  void onHorizontalDragLeft(DragUpdateDetails details) {
    double rightPos = currentWidth + x;
    double newX = x + details.delta.dx;
    double newWidth = currentWidth - details.delta.dx;

    if (newWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
      x = rightPos - currentWidth;
    } else if (newX <= 0) {
      x = 0;
      currentWidth = rightPos; // why not rightPos-x? because x is 0
    } else {
      x = newX;
      currentWidth = newWidth;
    }
    notifyListeners();
  }

  void onHorizontalDragRight(DragUpdateDetails details) {
    currentWidth += details.delta.dx;
    if (currentWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
    }
    notifyListeners();
  }

  void onHorizontalDragBottom(DragUpdateDetails details) {
    currentHeight += details.delta.dy;
    if (currentHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
    }
    notifyListeners();
  }

  void onHorizontalDragTop(DragUpdateDetails details) {
    double bottomPos = currentHeight + y;
    double newY = y + details.delta.dy;
    double newHeight = currentHeight - details.delta.dy;
    if (newHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
      y = bottomPos - currentHeight;
    } else if (newY <= 0) {
      y = 0;
      currentHeight = bottomPos; // why not bottomPos-y? because y is 0
    } else {
      y = newY;
      currentHeight = newHeight;
    }
    notifyListeners();
  }

  void onHorizontalDragBottomRight(DragUpdateDetails details) {
    // Avoid double notification by manipulating variables directly or batching?
    // calling notifyListeners in both sub-methods will trigger 2 notifies per frame.
    // It's better to implement logic here or create private non-notifying methods.
    // For simplicity, we just reuse the logic but suppress notification if possible,
    // or just let it notify twice (UI will just rebuild twice, frame outcome is same).
    // Optimization: Inline logic to notify once.

    // Right logic
    currentWidth += details.delta.dx;
    if (currentWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
    }

    // Bottom logic
    currentHeight += details.delta.dy;
    if (currentHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
    }

    notifyListeners();
  }

  void onHorizontalDragBottomLeft(DragUpdateDetails details) {
    // Left logic
    double rightPos = currentWidth + x;
    double newX = x + details.delta.dx;
    double newWidth = currentWidth - details.delta.dx;

    if (newWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
      x = rightPos - currentWidth;
    } else if (newX <= 0) {
      x = 0;
      currentWidth = rightPos;
    } else {
      x = newX;
      currentWidth = newWidth;
    }

    // Bottom logic
    currentHeight += details.delta.dy;
    if (currentHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
    }

    notifyListeners();
  }

  void onHorizontalDragTopRight(DragUpdateDetails details) {
    // Right logic
    currentWidth += details.delta.dx;
    if (currentWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
    }

    // Top logic
    double bottomPos = currentHeight + y;
    double newY = y + details.delta.dy;
    double newHeight = currentHeight - details.delta.dy;
    if (newHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
      y = bottomPos - currentHeight;
    } else if (newY <= 0) {
      y = 0;
      currentHeight = bottomPos;
    } else {
      y = newY;
      currentHeight = newHeight;
    }

    notifyListeners();
  }

  void onHorizontalDragTopLeft(DragUpdateDetails details) {
    // Left logic
    double rightPos = currentWidth + x;
    double newX = x + details.delta.dx;
    double newWidth = currentWidth - details.delta.dx;

    if (newWidth < _parameter.minWidth) {
      currentWidth = _parameter.minWidth;
      x = rightPos - currentWidth;
    } else if (newX <= 0) {
      x = 0;
      currentWidth = rightPos;
    } else {
      x = newX;
      currentWidth = newWidth;
    }

    // Top logic
    double bottomPos = currentHeight + y;
    double newY = y + details.delta.dy;
    double newHeight = currentHeight - details.delta.dy;
    if (newHeight < _parameter.minHeight) {
      currentHeight = _parameter.minHeight;
      y = bottomPos - currentHeight;
    } else if (newY <= 0) {
      y = 0;
      currentHeight = bottomPos;
    } else {
      y = newY;
      currentHeight = newHeight;
    }

    notifyListeners();
  }

  void toggleMaximize(Size screenSize, [bool? isMaximize]) {
    if (isMaximize == isMaximized) return;

    if (isMaximized) {
      x = lastPosition.width;
      y = lastPosition.height;
      currentWidth = lastSize.width;
      currentHeight = lastSize.height;
    } else {
      lastPosition = Size(x, y);
      lastSize = Size(currentWidth, currentHeight);

      x = 0;
      y = 0;
      currentWidth = screenSize.width;
      currentHeight = screenSize.height;
    }
    isMaximized = !isMaximized;
    notifyListeners();
  }

  Widget dragWidget({required Widget child, bool canDoubleClick = true}) {
    return GestureDetector(
      supportedDevices: const {PointerDeviceKind.mouse},
      onTap: () {
        requestFocus();
        if (canDoubleClick) {
          int now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastTap < 300) {
            _consecutiveTaps++;
            if (_consecutiveTaps >= 2) {
              _toggleMaximize?.call((screenSize) => toggleMaximize(screenSize));
            }
          }
          _consecutiveTaps = 1;
          _lastTap = now;
        }
      },
      onPanStart: (details) {
        if (!isMaximized) requestFocus();
      },
      onPanUpdate: (tapInfo) {
        if (isMaximized) return;
        requestFocus();
        x += tapInfo.delta.dx;
        y += tapInfo.delta.dy;
        x = x.clamp(0.0, double.infinity);
        y = y.clamp(0.0, double.infinity);
        notifyListeners();
      },
      onPanEnd: (details) {
        if (isMaximized) return;
        onWindowDragEnd();
        positionChangeAction();
      },
      child: child,
    );
  }

  bool Function(KeyEvent event)? onKeyEvent;
}
