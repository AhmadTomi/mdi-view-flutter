part of '../../mdi_view.dart';

class ResizableWindow extends StatefulWidget {
  final ResizeableWindowController controller;

  const ResizableWindow({super.key, required this.controller});

  @override
  State<ResizableWindow> createState() => ResizableWindowState();
}

class ResizableWindowState extends State<ResizableWindow> {
  late final ResizeableWindowController controller;
  late final Widget cachedChildContent;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    controller.addListener(_rebuildWidget);
    cachedChildContent = RepaintBoundary(
      child: AnimatedBuilder(
        // Listen to the FocusScopeNode, NOT the controller
        animation: controller.focusScopeNode,
        builder: (BuildContext context, Widget? child) {
          // This builder only runs on focus changes,
          // rebuilding the header/content with the new state.
          return controller.child(controller);
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.requestFocus();
    });
  }

  @override
  void dispose() {
    if (!controller.isDisposed) {
      controller.removeListener(_rebuildWidget);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: controller.y,
      left: controller.x,
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.all(controller.widgetPadding),
          child: _windowBuilder(),
        ),
      ),
    );
  }

  void _rebuildWidget() {
    if (context.mounted) {
      setState(() {});
    }
  }

  void rebuild() {
    setState(() {});
  }

  Widget _windowBuilder() {
    final mdiStyle = MdiStyleProvider.of(context);
    final gap = mdiStyle.gap;
    return ResizableWindowProvider(
      controller: controller,
      child: Padding(
        padding: EdgeInsets.all(controller.isMaximized ? 0 : gap),
        child: FocusScope(
          node: controller.focusScopeNode,
          onKeyEvent: (node, event) {
            if (event.synthesized || event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }

            final isHandled = controller.onKeyEvent?.call(event) ?? false;
            return isHandled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          onFocusChange: (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _rebuildWidget();
                controller.onFocusChange?.call(value);
              }
            });
          },
          child: GestureDetector(
            onTap: (controller.hasFocus) ? null : controller.requestFocus,
            child: Container(
              decoration: ShapeDecoration(
                color: mdiStyle.windowBackgroundColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: controller.isMaximized
                        ? mdiStyle.maximizedBorderColor
                        : controller.hasFocus
                        ? mdiStyle.focusedBorderColor
                        : mdiStyle.unfocusedBorderColor,
                    width: 1.2,
                    strokeAlign: 0,
                  ),
                  borderRadius: BorderRadius.circular(
                    controller.isMaximized ? 0 : mdiStyle.borderRadius,
                  ),
                ),
              ),
              width:
                  controller.currentWidth -
                  (controller.isMaximized ? 0 : (2 * gap)),
              height:
                  controller.currentHeight -
                  (controller.isMaximized ? 0 : (2 * gap)),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: ClipRRect(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadiusGeometry.circular(
                  controller.isMaximized ? 0 : mdiStyle.borderRadius - 1,
                ),
                child: SizedBox(
                  height: controller.currentHeight + gap,
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: Column(
                          children: [Expanded(child: cachedChildContent)],
                        ),
                      ),
                      IgnorePointer(
                        ignoring: true,
                        child: ColoredBox(
                          color: controller.hasFocus
                              ? Colors.transparent
                              : mdiStyle.unfocusBlockerColor,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: (details) =>
                                controller.requestFocus(),
                            onHorizontalDragUpdate: (details) {
                              controller.onHorizontalDragRight(details);
                            },
                            onHorizontalDragEnd: (details) {
                              controller.onHorizontalRightDragEnd(details);
                              controller.positionChangeAction();
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              opaque: true,
                              child: SizedBox(width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onHorizontalDragStart: (details) =>
                                controller.requestFocus(),
                            onHorizontalDragUpdate: (details) {
                              controller.onHorizontalDragLeft(details);
                            },
                            onHorizontalDragEnd: (details) {
                              controller.onHorizontalLeftDragEnd(details);
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              opaque: true,
                              child: SizedBox(width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onVerticalDragStart: (details) =>
                                controller.requestFocus(),
                            onVerticalDragUpdate: (details) {
                              controller.onHorizontalDragTop(details);
                            },
                            onVerticalDragEnd: (details) {
                              controller.onVerticalDragTopEnd(details);
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpDown,
                              opaque: true,
                              child: SizedBox(height: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onVerticalDragStart: (details) =>
                                controller.requestFocus(),
                            onVerticalDragUpdate: (details) {
                              controller.onHorizontalDragBottom(details);
                            },
                            onVerticalDragEnd: (details) {
                              controller.onVerticalDragBottomEnd(details);
                              controller.positionChangeAction();
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpDown,
                              opaque: true,
                              child: SizedBox(height: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onPanStart: (details) => controller.requestFocus(),
                            onPanUpdate: (details) {
                              controller.onHorizontalDragBottomRight(details);
                            },
                            onPanEnd: (details) {
                              controller.positionChangeAction();
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpLeftDownRight,
                              opaque: true,
                              child: SizedBox.square(dimension: 12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onPanStart: (details) => controller.requestFocus(),
                            onPanUpdate: (details) {
                              controller.onHorizontalDragBottomLeft(details);
                            },
                            onPanEnd: (details) {
                              controller.positionChangeAction();
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpRightDownLeft,
                              opaque: true,
                              child: SizedBox.square(dimension: 12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onPanStart: (details) => controller.requestFocus(),
                            onPanUpdate: (details) {
                              controller.onHorizontalDragTopRight(details);
                            },
                            onPanEnd: (details) {
                              controller.positionChangeAction();
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpRightDownLeft,
                              opaque: true,
                              child: SizedBox.square(dimension: 12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        child: IgnorePointer(
                          ignoring: controller.isMaximized,
                          child: GestureDetector(
                            onPanStart: (details) => controller.requestFocus(),
                            onPanUpdate: (details) {
                              controller.onHorizontalDragTopLeft(details);
                            },
                            onPanEnd: (details) {
                              // widget.onWindowResized(controller.x,controller.y,controller.currentWidth,controller.currentHeight);
                            },
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.resizeUpLeftDownRight,
                              opaque: true,
                              child: SizedBox.square(dimension: 12),
                            ),
                          ),
                        ),
                      ),
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

class ResizableWindowProvider extends InheritedWidget {
  final ResizeableWindowController controller;

  const ResizableWindowProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static ResizeableWindowController? of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<ResizableWindowProvider>();
    return result?.controller;
  }

  @override
  bool updateShouldNotify(ResizableWindowProvider oldWidget) {
    return oldWidget.controller != controller;
  }
}
