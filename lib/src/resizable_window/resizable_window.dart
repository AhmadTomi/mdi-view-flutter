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
        animation: Listenable.merge([
          _controller.focusScopeNode,
          _controller.hoverNotifier,
        ]),
        builder: (_, _) => _controller.child(_controller),
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

  Widget? _cachedChrome;
  double? _lastWidth;
  double? _lastHeight;
  bool? _lastMaximized;
  bool? _lastFocus;
  bool? _lastHover;
  String? _lastTitle;
  double? _lastDpr;
  MdiStyleConfiguration? _lastStyle;

  @override
  Widget build(BuildContext context) {
    // Use the total effective pixel ratio (real screen DPR * zoom)
    final double scaledDpr = MediaQuery.devicePixelRatioOf(context);
    final style = MdiStyleProvider.of(context);

    // Snap to the nearest EXACT physical device pixel
    double snap(double value) =>
        (value * scaledDpr).roundToDouble() / scaledDpr;

    final bool chromeNeedsRebuild = _cachedChrome == null ||
        _lastWidth != _controller.currentWidth ||
        _lastHeight != _controller.currentHeight ||
        _lastMaximized != _controller.isMaximized ||
        _lastFocus != _controller.hasFocus ||
        _lastHover != _controller.isHovered ||
        _lastTitle != _controller.title ||
        _lastDpr != scaledDpr ||
        _lastStyle != style;

    if (chromeNeedsRebuild) {
      _lastWidth = _controller.currentWidth;
      _lastHeight = _controller.currentHeight;
      _lastMaximized = _controller.isMaximized;
      _lastFocus = _controller.hasFocus;
      _lastHover = _controller.isHovered;
      _lastTitle = _controller.title;
      _lastDpr = scaledDpr;
      _lastStyle = style;
      _cachedChrome = RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.all(_controller.widgetPadding),
          // Pass the snap function down
          child: _buildWindowChrome(context, snap),
        ),
      );
    }

    return Positioned(
      top: snap(_controller.y),
      left: snap(_controller.x),
      child: MouseRegion(
        onEnter: (_) => _controller.setHover(true),
        onExit: (_) => _controller.setHover(false),
        child: _cachedChrome!,
      ),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Widget _buildWindowChrome(
    BuildContext context,
    double Function(double) snap,
  ) {
    final style = MdiStyleProvider.of(context);
    final double rawGap = _controller.isMaximized ? 0.0 : style.gap.toDouble();
    final double snappedGap = snap(rawGap);
    final radius = _controller.isMaximized
        ? 0.0
        : style.borderRadius.toDouble();

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
      child: nestedNavigator,
    );

    final Widget windowContent;
    if (style.showDefaultHeader) {
      windowContent = Column(
        children: [
          // Default Draggable Header
          _controller.dragWidget(
            child: Container(
              height: style.defaultHeaderHeight,
              color: _controller.hasFocus
                  ? style.focusedHeaderColor
                  : style.unfocusedHeaderColor,
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

    final Widget windowContentWithScroll = Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (_controller.shouldIgnoreDrag(pointerSignal.position)) {
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (event) {},
            );
          } else {
            GestureBinding.instance.pointerSignalResolver.register(
              pointerSignal,
              (event) {
                if (event is PointerScrollEvent) {
                  _controller.onWorkspacePointerScroll?.call(event);
                }
              },
            );
          }
        }
      },
      child: windowContent,
    );

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
            void update() {
              if (mounted) {
                _onControllerUpdate();
                _controller.onFocusChange?.call(focused);
              }
            }

            if (WidgetsBinding.instance.schedulerPhase ==
                SchedulerPhase.persistentCallbacks) {
              WidgetsBinding.instance.addPostFrameCallback((_) => update());
            } else {
              update();
            }
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (!_controller.hasFocus) {
                _controller.requestFocus();
                _controller.bringToFront();
              }
            },
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.all(snappedGap),
                child: SizedBox(
                  width: snap(_controller.currentWidth) - 2 * snappedGap,
                  height: snap(_controller.currentHeight) - 2 * snappedGap,
                  child: WindowResizeFrame(
                    controller: _controller,
                    enabled: !_controller.isMaximized,
                    child: Stack(
                      children: [
                        // ── Window surface ──────────────────────────────────
                        _WindowSurface(
                          controller: _controller,
                          style: style,
                          radius: radius,
                          content: style.draggableBody
                              ? _controller.dragWidget(
                                  child: windowContentWithScroll,
                                  canDoubleClick: false,
                                  useGestureDetector: true,
                                )
                              : windowContentWithScroll,
                        ),

                        // ── Unfocus overlay ─────────────────────────────────
                        _UnfocusBlocker(
                          color: style.unfocusBlockerColor,
                          active: !_controller.hasFocus && !_controller.isHovered,
                          radius: radius,
                          controller: _controller,
                        ),
                      ],
                    ),
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
  final double radius;
  final ResizeableWindowController controller;

  const _UnfocusBlocker({
    required this.color,
    required this.active,
    required this.radius,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return const SizedBox.shrink();
    }

    final child = ClipRRect(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: color,
        child: const SizedBox.expand(),
      ),
    );

    return controller.dragWidget(canDoubleClick: false, child: child);
  }
}

// ── Resize edge and corner enums ─────────────────────────────────────────────

enum EdgeSide { left, right, top, bottom }

enum CornerSide { topLeft, topRight, bottomLeft, bottomRight }

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
