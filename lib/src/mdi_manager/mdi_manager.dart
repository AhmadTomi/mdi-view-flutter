part of '../../mdi_view.dart';

// ── MdiManager ────────────────────────────────────────────────────────────────

/// Root widget for the MDI surface.
///
/// Responsibilities:
///   • Provides [MdiStyleProvider] to the subtree.
///   • Renders the tab strip ([MdiTabWidget]) and the scrollable MDI canvas.
///   • Tracks [LayoutBuilder] size changes and updates [MdiController].
///   • Hosts the dual scroll-bar setup (primary + right-side thumb scrollbar).
class MdiManager extends StatefulWidget {
  final MdiController controller;
  final MdiStyleConfiguration? style;

  /// Optional host-level key event handler (runs before the MDI default
  /// bindings; return `true` to consume the event).
  final bool Function(KeyEvent event)? onKeyEvent;

  const MdiManager({
    super.key,
    required this.controller,
    this.style,
    this.onKeyEvent,
  });

  @override
  State<MdiManager> createState() => _MdiManagerState();
}

class _MdiManagerState extends State<MdiManager> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return MdiStyleProvider(
      style: widget.style ?? MdiStyleConfiguration.defaults,
      child: FocusScope(
        onFocusChange: ctrl.onFocusChange,
        onKeyEvent: (_, event) {
          if (widget.onKeyEvent?.call(event) ?? false) {
            return KeyEventResult.handled;
          }
          return ctrl.onKeyEvent(event)
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        },
        child: Builder(
          builder: (ctx) => ColoredBox(
            color: MdiStyleProvider.of(ctx).mdiBackgroundColor,
            child: Column(
              children: [
                MdiTabWidget(ctrl),
                Expanded(child: _MdiCanvas(controller: ctrl)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _MdiCanvas ────────────────────────────────────────────────────────────────

/// The scrollable 2-D canvas that hosts all [ResizableWindow] widgets.
class _MdiCanvas extends StatelessWidget {
  final MdiController controller;

  const _MdiCanvas({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          _updateScreenSize(constraints.biggest);

          final isMax = controller.isMaximize;

          return ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              overscroll: false,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.trackpad,
              },
              scrollbars: false,
              physics: isMax
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
            ),
            child: Stack(
              children: [
                // ── Main 2-D scroll area ───────────────────────────────────
                SizedBox.expand(
                  child: Scrollbar(
                    trackVisibility: false,
                    thumbVisibility: !isMax,
                    interactive: !isMax,
                    thickness: 4,
                    controller: controller.horizontalController,
                    child: SingleChildScrollView(
                      controller: controller.horizontalController,
                      scrollDirection: Axis.horizontal,
                      hitTestBehavior: HitTestBehavior.opaque,
                      child: SingleChildScrollView(
                        controller: controller.verticalController,
                        scrollDirection: Axis.vertical,
                        hitTestBehavior: HitTestBehavior.opaque,
                        child: SizedBox.fromSize(
                          size: controller.mdiSize,
                          child: RepaintBoundary(
                            child: Stack(
                              children: controller.windows
                                  .map(
                                    (c) => ResizableWindow(
                                      key: ValueKey(c.tag),
                                      controller: c,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Right-edge vertical scrollbar thumb ────────────────────
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Scrollbar(
                    controller: controller.verticalScrollBarController,
                    trackVisibility: false,
                    thumbVisibility: !isMax,
                    interactive: !isMax,
                    thickness: 4,
                    child: SingleChildScrollView(
                      controller: controller.verticalScrollBarController,
                      hitTestBehavior: HitTestBehavior.opaque,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        width: 20,
                        height: controller.mdiSize.height.clamp(
                          constraints.maxHeight,
                          double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateScreenSize(Size size) {
    if (controller.mdiSize == Size.zero) {
      controller.mdiSize = size;
    }

    if (controller.screenSize == size) return;

    controller.screenSize = size;
    controller.calculateUpdateScreenSize();

    if (controller.isMaximize) {
      controller.frontWindow?.updateParameter(
        x: 0,
        y: 0,
        currentHeight: size.height,
        currentWidth: size.width,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.tabMenuController.tabScrollCheck();
    });
  }
}

// Add the public alias so MdiManager continues to compile against
// the renamed internal method.
extension on MdiController {
  void calculateUpdateScreenSize() => _recalculateMdiSize();
}
