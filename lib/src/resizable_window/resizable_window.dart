part of '../../mdi_view.dart';

// ── ResizableWindow ───────────────────────────────────────────────────────────

/// A positioned, resizable, focusable MDI child window.
///
/// Layout responsibilities:
///   • Positions itself via [Positioned] inside the MDI [Stack].
///   • Delegates all geometry mutation to [ResizeableWindowController].
///   • Caches the content widget so it does **not** rebuild on every
///     position/size change — only on focus changes.
class ResizableWindow extends StatefulWidget {
  final ResizeableWindowController controller;

  const ResizableWindow({super.key, required this.controller});

  @override
  State<ResizableWindow> createState() => ResizableWindowState();
}

class ResizableWindowState extends State<ResizableWindow> {
  late final ResizeableWindowController _controller;

  /// The content widget is built once and cached.  It listens to
  /// [focusScopeNode] directly so focus changes re-run the builder without
  /// rebuilding the entire window chrome.
  late final Widget _cachedContent;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerUpdate);

    _cachedContent = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller.focusScopeNode,
        builder: (_, __) => _controller.child(_controller),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.requestFocus();
    });
  }

  @override
  void dispose() {
    if (!_controller.isDisposed) {
      _controller.removeListener(_onControllerUpdate);
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Use the total effective pixel ratio (real screen DPR * zoom)
    final double scaledDpr = MediaQuery.devicePixelRatioOf(context);

    // Snap to the nearest EXACT physical device pixel
    double snap(double value) => (value * scaledDpr).roundToDouble() / scaledDpr;

    return Positioned(
      top: snap(_controller.y),
      left: snap(_controller.x),
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.all(_controller.widgetPadding),
          // Pass the snap function down
          child: _buildWindowChrome(context, snap),
        ),
      ),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Widget _buildWindowChrome(BuildContext context, double Function(double) snap) {
    final style = MdiStyleProvider.of(context);
    final double rawGap = _controller.isMaximized ? 0.0 : style.gap.toDouble();
    final double snappedGap = snap(rawGap);
    final radius = _controller.isMaximized ? 0.0 : style.borderRadius.toDouble();

    final Widget nestedNavigator = Navigator(
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => _cachedContent,
        );
      },
    );

    final Widget childContent = NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (event) {},
            );
          }
        },
        child: nestedNavigator,
      ),
    );

    final Widget windowContent;
    if (style.showDefaultHeader) {
      windowContent = Column(
        children: [
          // Default Draggable Header
          _controller.dragWidget(
            child: Container(
              height: style.defaultHeaderHeight,
              color: _controller.hasFocus ? style.focusedHeaderColor : style.unfocusedHeaderColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _controller.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: style.defaultHeaderTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _controller.close,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: style.defaultHeaderTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content Area
          Expanded(child: childContent),
        ],
      );
    } else {
      windowContent = childContent;
    }

    return ResizableWindowProvider(
      controller: _controller,
      child: Padding(
        padding: EdgeInsets.all(snappedGap),
        child: FocusScope(
          node: _controller.focusScopeNode,
          onKeyEvent: (_, event) {
            if (event.synthesized || event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            return (_controller.onKeyEvent?.call(event) ?? false)
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          },
          onFocusChange: (focused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _onControllerUpdate();
                _controller.onFocusChange?.call(focused);
              }
            });
          },
          child: GestureDetector(
            onTap: _controller.hasFocus ? null : _controller.requestFocus,
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.all(snappedGap),
                child: SizedBox(
                  width: snap(_controller.currentWidth) - 2 * snappedGap,
                  height: snap(_controller.currentHeight) - 2 * snappedGap,
                  child: Stack(
                    children: [
                      // ── Window surface ──────────────────────────────────
                      _WindowSurface(
                        controller: _controller,
                        style: style,
                        radius: radius,
                        content: style.draggableBody
                            ? _controller.dragWidget(child: windowContent, canDoubleClick: false)
                            : windowContent,
                      ),

                      // ── Unfocus overlay ─────────────────────────────────
                      _UnfocusBlocker(
                        color: style.unfocusBlockerColor,
                        active: !_controller.hasFocus,
                        controller: _controller,
                      ),

                      // ── Resize handles ──────────────────────────────────
                      if (!_controller.isMaximized) ...[
                        _EdgeHandle.right(_controller),
                        _EdgeHandle.left(_controller),
                        _EdgeHandle.top(_controller),
                        _EdgeHandle.bottom(_controller),
                        _CornerHandle.bottomRight(_controller),
                        _CornerHandle.bottomLeft(_controller),
                        _CornerHandle.topRight(_controller),
                        _CornerHandle.topLeft(_controller),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Window surface ────────────────────────────────────────────────────────────

class _WindowSurface extends StatelessWidget {
  final ResizeableWindowController controller;
  final MdiStyleConfiguration style;
  final double radius;
  final Widget content;

  const _WindowSurface({
    required this.controller,
    required this.style,
    required this.radius,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = controller.isMaximized
        ? style.maximizedBorderColor
        : controller.hasFocus
        ? style.focusedBorderColor
        : style.unfocusedBorderColor;

    return SizedBox.expand(
      child: ClipRRect(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          color: borderColor,
          padding: EdgeInsets.all(style.borderWidth.toDouble()),
          child: ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(radius),
            child: ColoredBox(
              color: style.windowBackgroundColor,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unfocus overlay ───────────────────────────────────────────────────────────

class _UnfocusBlocker extends StatelessWidget {
  final Color color;
  final bool active;
  final ResizeableWindowController controller;

  const _UnfocusBlocker({
    required this.color,
    required this.active,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final child = IgnorePointer(
      ignoring: !active,
      child: AbsorbPointer(
        absorbing: active,
        child: ColoredBox(
          color: active ? color : Colors.transparent,
          child: const SizedBox.expand(),
        ),
      ),
    );

    // Only wrap in dragWidget when the window is unfocused so that
    // clicking the blocker starts a seamless drag.  When focused,
    // the blocker must be fully transparent to pointer events — otherwise
    // its Listener fires startDrag on every click and interferes with
    // the header's GestureDetector double-tap / maximize logic.
    if (active) {
      return controller.dragWidget(
        canDoubleClick: false,
        child: child,
      );
    }

    return child;
  }
}

// ── Edge resize handle ────────────────────────────────────────────────────────

enum EdgeSide { left, right, top, bottom }

class _EdgeHandle extends StatelessWidget {
  final ResizeableWindowController controller;
  final EdgeSide side;

  const _EdgeHandle.right(this.controller) : side = EdgeSide.right;
  const _EdgeHandle.left(this.controller) : side = EdgeSide.left;
  const _EdgeHandle.top(this.controller) : side = EdgeSide.top;
  const _EdgeHandle.bottom(this.controller) : side = EdgeSide.bottom;

  bool get _isHorizontal =>
      side == EdgeSide.left || side == EdgeSide.right;

  @override
  Widget build(BuildContext context) {
    // Horizontal edges (left/right) need a full-height strip, so top and
    // bottom are pinned to 0. Vertical edges (top/bottom) need a full-width
    // strip, so left and right are pinned to 0. Without this, the
    // unpinned axis collapses to the child's intrinsic size — which is 0,
    // since the SizedBox below only declares a size on its own axis.
    return Positioned(
      left: side == EdgeSide.left
          ? 0
          : (!_isHorizontal ? 0 : null),
      right: side == EdgeSide.right
          ? 0
          : (!_isHorizontal ? 0 : null),
      top: side == EdgeSide.top
          ? 0
          : (_isHorizontal ? 0 : null),
      bottom: side == EdgeSide.bottom
          ? 0
          : (_isHorizontal ? 0 : null),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            controller.startResize(event, side: side);
          }
        },
        child: MouseRegion(
          cursor: _isHorizontal
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.resizeUpDown,
          opaque: true,
          child: _isHorizontal
              ? const SizedBox(width: 4)
              : const SizedBox(height: 4),
        ),
      ),
    );
  }
}

// ── Corner resize handle ──────────────────────────────────────────────────────

enum CornerSide { topLeft, topRight, bottomLeft, bottomRight }

class _CornerHandle extends StatelessWidget {
  final ResizeableWindowController controller;
  final CornerSide side;

  const _CornerHandle.bottomRight(this.controller)
      : side = CornerSide.bottomRight;
  const _CornerHandle.bottomLeft(this.controller)
      : side = CornerSide.bottomLeft;
  const _CornerHandle.topRight(this.controller) : side = CornerSide.topRight;
  const _CornerHandle.topLeft(this.controller) : side = CornerSide.topLeft;

  MouseCursor get _cursor => switch (side) {
    CornerSide.topLeft || CornerSide.bottomRight =>
    SystemMouseCursors.resizeUpLeftDownRight,
    CornerSide.topRight || CornerSide.bottomLeft =>
    SystemMouseCursors.resizeUpRightDownLeft,
  };

  @override
  Widget build(BuildContext context) {
    final bool isLeft =
        side == CornerSide.topLeft || side == CornerSide.bottomLeft;
    final bool isTop =
        side == CornerSide.topLeft || side == CornerSide.topRight;

    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse) {
            controller.startResize(event, corner: side);
          }
        },
        child: MouseRegion(
          cursor: _cursor,
          opaque: true,
          child: const SizedBox.square(dimension: 12),
        ),
      ),
    );
  }
}

// ── InheritedWidget ───────────────────────────────────────────────────────────

/// Provides the nearest [ResizeableWindowController] to descendant widgets.
class ResizableWindowProvider extends InheritedWidget {
  final ResizeableWindowController controller;

  const ResizableWindowProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static ResizeableWindowController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ResizableWindowProvider>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(ResizableWindowProvider oldWidget) =>
      oldWidget.controller != controller;
}

// ── IgnoreWindowDrag ──────────────────────────────────────────────────────────

/// A widget that prevents window drag operations when a pointer gesture
/// starts inside its bounds.
///
/// Use this to wrap interactive child widgets (like `InAppWebView`, scrollable views,
/// or maps) that should consume pointer/drag events and prevent the parent MDI window
/// from being dragged instead.
class IgnoreWindowDrag extends StatefulWidget {
  final Widget child;

  const IgnoreWindowDrag({super.key, required this.child});

  @override
  State<IgnoreWindowDrag> createState() => _IgnoreWindowDragState();
}

class _IgnoreWindowDragState extends State<IgnoreWindowDrag> {
  ResizeableWindowController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = ResizableWindowProvider.of(context);
    if (_controller != newController) {
      _controller?.unregisterIgnoreDragContext(context);
      _controller = newController;
      _controller?.registerIgnoreDragContext(context);
    }
  }

  @override
  void dispose() {
    _controller?.unregisterIgnoreDragContext(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}