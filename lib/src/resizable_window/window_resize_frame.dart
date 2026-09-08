part of '../../mdi_view.dart';

// ── WindowResizeFrame ────────────────────────────────────────────────────────

/// A render object widget that provides 8-way resize handle detection
/// (4 edges + 4 corners) directly in the render pipeline without requiring
/// multiple nested [Positioned], [Listener], and [MouseRegion] widgets.
class WindowResizeFrame extends SingleChildRenderObjectWidget {
  final ResizeableWindowController controller;
  final bool enabled;

  const WindowResizeFrame({
    super.key,
    required this.controller,
    required this.enabled,
    required super.child,
  });

  @override
  RenderWindowResizeFrame createRenderObject(BuildContext context) {
    return RenderWindowResizeFrame(
      controller: controller,
      enabled: enabled,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderWindowResizeFrame renderObject,
  ) {
    renderObject
      ..controller = controller
      ..enabled = enabled;
  }
}

// ── RenderWindowResizeFrame ──────────────────────────────────────────────────

class _HandleInfo {
  final EdgeSide? side;
  final CornerSide? corner;
  final MouseCursor cursor;

  const _HandleInfo({this.side, this.corner, required this.cursor});
}

/// [RenderProxyBox] that detects mouse hover on window borders/corners to
/// display native resize cursors and initiates window resizing on pointer down.
class RenderWindowResizeFrame extends RenderProxyBox
    implements MouseTrackerAnnotation {
  ResizeableWindowController _controller;
  bool _enabled;
  MouseCursor _cursor = MouseCursor.defer;

  RenderWindowResizeFrame({
    required ResizeableWindowController controller,
    required bool enabled,
    RenderBox? child,
  })  : _controller = controller,
        _enabled = enabled,
        super(child);

  ResizeableWindowController get controller => _controller;
  set controller(ResizeableWindowController value) {
    if (_controller == value) return;
    _controller = value;
  }

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsPaint();
  }

  // ── MouseTrackerAnnotation ─────────────────────────────────────────────────

  @override
  MouseCursor get cursor => _cursor;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => true;

  // ── Hit Testing ────────────────────────────────────────────────────────────

  static const double _cornerSize = 12.0;
  static const double _edgeSize = 4.0;

  _HandleInfo? _hitTestHandles(Offset pos) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return null;

    // 1. Check corners first (take priority over edges)
    if (pos.dx <= _cornerSize && pos.dy <= _cornerSize) {
      return const _HandleInfo(
        corner: CornerSide.topLeft,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
      );
    }
    if (pos.dx >= w - _cornerSize && pos.dy <= _cornerSize) {
      return const _HandleInfo(
        corner: CornerSide.topRight,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
      );
    }
    if (pos.dx <= _cornerSize && pos.dy >= h - _cornerSize) {
      return const _HandleInfo(
        corner: CornerSide.bottomLeft,
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
      );
    }
    if (pos.dx >= w - _cornerSize && pos.dy >= h - _cornerSize) {
      return const _HandleInfo(
        corner: CornerSide.bottomRight,
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
      );
    }

    // 2. Check edges
    if (pos.dy <= _edgeSize) {
      return const _HandleInfo(
        side: EdgeSide.top,
        cursor: SystemMouseCursors.resizeUpDown,
      );
    }
    if (pos.dy >= h - _edgeSize) {
      return const _HandleInfo(
        side: EdgeSide.bottom,
        cursor: SystemMouseCursors.resizeUpDown,
      );
    }
    if (pos.dx <= _edgeSize) {
      return const _HandleInfo(
        side: EdgeSide.left,
        cursor: SystemMouseCursors.resizeLeftRight,
      );
    }
    if (pos.dx >= w - _edgeSize) {
      return const _HandleInfo(
        side: EdgeSide.right,
        cursor: SystemMouseCursors.resizeLeftRight,
      );
    }

    return null;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;

    if (_enabled) {
      final handle = _hitTestHandles(position);
      if (handle != null) {
        _cursor = handle.cursor;
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }

    _cursor = MouseCursor.defer;
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent && event.kind == PointerDeviceKind.mouse) {
      final handle = _hitTestHandles(entry.localPosition);
      if (handle != null) {
        _controller.startResize(
          event,
          side: handle.side,
          corner: handle.corner,
        );
      }
    }
  }
}
