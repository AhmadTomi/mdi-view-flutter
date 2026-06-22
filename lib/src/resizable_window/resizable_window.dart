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
    return Positioned(
      top: _controller.renderY,
      left: _controller.renderX,
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.all(_controller.widgetPadding),
          child: _buildWindowChrome(context),
        ),
      ),
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Widget _buildWindowChrome(BuildContext context) {
    final style = MdiStyleProvider.of(context);
    final gap = _controller.isMaximized ? 0 : style.gap;
    final radius = _controller.isMaximized ? 0.0 : style.borderRadius.toDouble();

    return ResizableWindowProvider(
      controller: _controller,
      child: Padding(
        padding: EdgeInsets.all(gap.toDouble()),
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
                padding: EdgeInsets.all(gap.toDouble()),
                child: SizedBox(
                  width: _controller.renderWidth - 2 * gap,
                  height: _controller.renderHeight - 2 * gap,
                  child: Stack(
                    children: [
                      // ── Window surface ──────────────────────────────────
                      _WindowSurface(
                        controller: _controller,
                        style: style,
                        radius: radius,
                        content: _cachedContent,
                      ),

                      // ── Unfocus overlay ─────────────────────────────────
                      _UnfocusBlocker(
                        color: style.unfocusBlockerColor,
                        active: !_controller.hasFocus,
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
            child: content,
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

  const _UnfocusBlocker({required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: active ? color : Colors.transparent,
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Edge resize handle ────────────────────────────────────────────────────────

enum _EdgeSide { left, right, top, bottom }

class _EdgeHandle extends StatelessWidget {
  final ResizeableWindowController controller;
  final _EdgeSide side;

  const _EdgeHandle.right(this.controller) : side = _EdgeSide.right;
  const _EdgeHandle.left(this.controller) : side = _EdgeSide.left;
  const _EdgeHandle.top(this.controller) : side = _EdgeSide.top;
  const _EdgeHandle.bottom(this.controller) : side = _EdgeSide.bottom;

  bool get _isHorizontal =>
      side == _EdgeSide.left || side == _EdgeSide.right;

  @override
  Widget build(BuildContext context) {
    // Horizontal edges (left/right) need a full-height strip, so top and
    // bottom are pinned to 0. Vertical edges (top/bottom) need a full-width
    // strip, so left and right are pinned to 0. Without this, the
    // unpinned axis collapses to the child's intrinsic size — which is 0,
    // since the SizedBox below only declares a size on its own axis.
    return Positioned(
      left: side == _EdgeSide.left
          ? 0
          : (!_isHorizontal ? 0 : null),
      right: side == _EdgeSide.right
          ? 0
          : (!_isHorizontal ? 0 : null),
      top: side == _EdgeSide.top
          ? 0
          : (_isHorizontal ? 0 : null),
      bottom: side == _EdgeSide.bottom
          ? 0
          : (_isHorizontal ? 0 : null),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _isHorizontal
            ? (_) => controller.requestFocus()
            : null,
        onHorizontalDragUpdate: _isHorizontal ? _onDragUpdate : null,
        onHorizontalDragEnd: _isHorizontal ? _onDragEnd : null,
        onVerticalDragStart: !_isHorizontal
            ? (_) => controller.requestFocus()
            : null,
        onVerticalDragUpdate: !_isHorizontal ? _onDragUpdate : null,
        onVerticalDragEnd: !_isHorizontal ? _onDragEnd : null,
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

  void _onDragUpdate(DragUpdateDetails d) {
    switch (side) {
      case _EdgeSide.right:
        controller.onHorizontalDragRight(d);
      case _EdgeSide.left:
        controller.onHorizontalDragLeft(d);
      case _EdgeSide.top:
        controller.onHorizontalDragTop(d);
      case _EdgeSide.bottom:
        controller.onHorizontalDragBottom(d);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    switch (side) {
      case _EdgeSide.right:
        controller.onHorizontalRightDragEnd(d);
        controller.positionChangeAction();
      case _EdgeSide.left:
        controller.onHorizontalLeftDragEnd(d);
      case _EdgeSide.top:
        controller.onVerticalDragTopEnd(d);
      case _EdgeSide.bottom:
        controller.onVerticalDragBottomEnd(d);
        controller.positionChangeAction();
    }
  }
}

// ── Corner resize handle ──────────────────────────────────────────────────────

enum _CornerSide { topLeft, topRight, bottomLeft, bottomRight }

class _CornerHandle extends StatelessWidget {
  final ResizeableWindowController controller;
  final _CornerSide side;

  const _CornerHandle.bottomRight(this.controller)
      : side = _CornerSide.bottomRight;
  const _CornerHandle.bottomLeft(this.controller)
      : side = _CornerSide.bottomLeft;
  const _CornerHandle.topRight(this.controller) : side = _CornerSide.topRight;
  const _CornerHandle.topLeft(this.controller) : side = _CornerSide.topLeft;

  MouseCursor get _cursor => switch (side) {
    _CornerSide.topLeft || _CornerSide.bottomRight =>
    SystemMouseCursors.resizeUpLeftDownRight,
    _CornerSide.topRight || _CornerSide.bottomLeft =>
    SystemMouseCursors.resizeUpRightDownLeft,
  };

  @override
  Widget build(BuildContext context) {
    final bool isLeft =
        side == _CornerSide.topLeft || side == _CornerSide.bottomLeft;
    final bool isTop =
        side == _CornerSide.topLeft || side == _CornerSide.topRight;

    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      child: GestureDetector(
        onPanStart: (_) => controller.requestFocus(),
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => controller.positionChangeAction(),
        child: MouseRegion(
          cursor: _cursor,
          opaque: true,
          child: const SizedBox.square(dimension: 12),
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails d) {
    switch (side) {
      case _CornerSide.bottomRight:
        controller.onHorizontalDragBottomRight(d);
      case _CornerSide.bottomLeft:
        controller.onHorizontalDragBottomLeft(d);
      case _CornerSide.topRight:
        controller.onHorizontalDragTopRight(d);
      case _CornerSide.topLeft:
        controller.onHorizontalDragTopLeft(d);
    }
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