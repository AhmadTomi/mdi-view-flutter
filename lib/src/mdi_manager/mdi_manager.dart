part of '../../mdi_view.dart';

class MdiManager extends StatefulWidget {
  final MdiController controller;
  final MdiStyleConfiguration? style;
  const MdiManager({super.key, required this.controller, this.style});
  @override
  State<MdiManager> createState() => _MdiManagerState();
}

class _MdiManagerState extends State<MdiManager> {
  @override
  void initState() {
    widget.controller.addListener(_rebuildWidget);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuildWidget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MdiStyleProvider(
      style: widget.style ?? MdiStyleConfiguration(),
      child: FocusScope(
        onFocusChange: (value) {
          // No print needed here for production, but logic remains
          widget.controller.onFocusChange(value);
        },
        onKeyEvent: (node, event) {
          bool isHandled = widget.controller.onKeyEvent(event);
          return isHandled ? KeyEventResult.handled : KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) => ColoredBox(
            color: MdiStyleProvider.of(context).mdiBackgroundColor,
            child: Column(
              children: [
                MdiTabWidget(widget.controller),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        updateScreenSize(constraints.biggest);
                        return ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.trackpad,
                            },
                            scrollbars: false,
                            physics: widget.controller.isMaximize
                                ? const NeverScrollableScrollPhysics()
                                : const AlwaysScrollableScrollPhysics(),
                          ),
                          child: Stack(
                            children: [
                              SizedBox.expand(
                                child: Scrollbar(
                                  trackVisibility: false,
                                  thumbVisibility:
                                      !widget.controller.isMaximize,
                                  interactive: !widget.controller.isMaximize,
                                  thickness: 4,
                                  controller:
                                      widget.controller.horizontalController,
                                  child: SingleChildScrollView(
                                    controller:
                                        widget.controller.horizontalController,
                                    scrollDirection: Axis.horizontal,
                                    hitTestBehavior: HitTestBehavior.opaque,
                                    child: SingleChildScrollView(
                                      controller:
                                          widget.controller.verticalController,
                                      hitTestBehavior: HitTestBehavior.opaque,
                                      scrollDirection: Axis.vertical,
                                      child: SizedBox.fromSize(
                                        size: widget.controller.mdiSize,
                                        child: RepaintBoundary(
                                          child: Stack(
                                            children: widget.controller.windows
                                                .map((c) {
                                                  return ResizableWindow(
                                                    key: ValueKey(c.tag),
                                                    controller: c,
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Scrollbar(
                                  controller: widget
                                      .controller
                                      .verticalScrollBarController,
                                  trackVisibility: false,
                                  thumbVisibility:
                                      !widget.controller.isMaximize,
                                  interactive: !widget.controller.isMaximize,
                                  thickness: 4,
                                  child: SingleChildScrollView(
                                    controller: widget
                                        .controller
                                        .verticalScrollBarController,
                                    hitTestBehavior: HitTestBehavior.opaque,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Container(
                                      width: 20,
                                      color: Colors.transparent,
                                      height: widget.controller.mdiSize.height
                                          .clamp(
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void updateScreenSize(Size size) {
    final height = size.height;
    final width = size.width;

    Size newScreenSize = Size(width, height);

    if (widget.controller.mdiSize == Size.zero) {
      widget.controller.mdiSize = newScreenSize;
    }

    if (widget.controller.screenSize != newScreenSize) {
      widget.controller.screenSize = newScreenSize;
      widget.controller.calculateUpdateScreenSize();
      if (widget.controller.isMaximize)
        widget.controller.frontWindow?.updateParameter(
          x: 0,
          y: 0,
          currentHeight: newScreenSize.height,
          currentWidth: newScreenSize.width,
        );
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        widget.controller.tabMenuController.tabScrollCheck();
        _rebuildWidget();
      });
    }
  }

  void _rebuildWidget() {
    if (context.mounted) {
      setState(() {});
    }
  }
}
