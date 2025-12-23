part of 'mdi_tab.dart';

class MdiTabWidget extends StatefulWidget {
  final MdiController mdiController;
  const MdiTabWidget(this.mdiController, {super.key});

  @override
  State<MdiTabWidget> createState() => _MdiTabWidgetState();
}

class _MdiTabWidgetState extends State<MdiTabWidget> {
  late final MdiTabController controller;

  @override
  void initState() {
    controller = widget.mdiController.tabMenuController;
    controller.addListener(_rebuildWidget);
    super.initState();
  }

  @override
  void dispose() {
    controller.removeListener(_rebuildWidget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mdiStyle = MdiStyleProvider.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        controller.tabScrollCheck();
      }
    });
    return Container(
      color: mdiStyle.tabBackgroundColor,
      height: 24,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(child: reorderedTab(context)),

          Row(
            children: [
              const SizedBox(
                height: 32,
                width: 0.6,
                child: VerticalDivider(thickness: 0.6),
              ),
              if (controller.showTabNavButton)
                _ButtonContainer(
                  enable: controller.showLeftButton,
                  onTap: () {
                    controller.scrollLeft();
                  },
                  borderRadius: 0,
                  color: mdiStyle.focusedTabMenuColor.withValues(alpha: 0.4),
                  splashColor: mdiStyle.tabSplashColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_left_rounded,
                    size: 15,
                    color: mdiStyle.unfocusedTabTextColor,
                  ),
                ),
              if (controller.showTabNavButton)
                _ButtonContainer(
                  enable: controller.showRightButton,
                  onTap: () {
                    controller.scrollRight();
                  },
                  color: mdiStyle.focusedTabMenuColor.withValues(alpha: 0.4),
                  splashColor: mdiStyle.tabSplashColor,
                  borderRadius: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_right_rounded,
                    size: 15,
                    color: mdiStyle.unfocusedTabTextColor,
                  ),
                ),
              const SizedBox(
                height: 32,
                width: 0.6,
                child: VerticalDivider(thickness: 0.6),
              ),
              _ButtonContainer(
                onTap: () {
                  widget.mdiController.toggleMaximize();
                },
                borderRadius: 0,
                color: mdiStyle.tabBackgroundColor.withValues(alpha: 0.4),
                splashColor: mdiStyle.tabSplashColor,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Icon(
                  widget.mdiController.isMaximize
                      ? Icons.grid_view_rounded
                      : Icons.fit_screen_rounded,
                  size: 15,
                  opticalSize: 60,
                  color: mdiStyle.unfocusedTabTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _rebuildWidget() {
    if (context.mounted) {
      setState(() {});
    }
  }

  Widget reorderedTab(BuildContext context) {
    final list = controller.tabControllers;
    final mdiStyle = MdiStyleProvider.of(context);
    return ReorderableListView.builder(
      itemBuilder: (context, index) {
        final e = list[index];
        return ReorderableDragStartListener(
          key: ValueKey(index),
          enabled: true,
          index: index,
          child: _ButtonContainer(
            key: ValueKey(index),
            color: e.hasFocus
                ? mdiStyle.focusedTabMenuColor
                : mdiStyle.unfocusedTabMenuColor,
            borderRadius: 2,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            width: e.hasFocus ? null : mdiStyle.tabMenuMinWidth,
            splashColor: mdiStyle.tabSplashColor,
            margin: EdgeInsets.zero,
            onTap: () => e.requestFocus(),
            child: Row(
              spacing: 6,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: e.hasFocus ? 0 : 1,
                  child: Text(
                    e.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: e.hasFocus ? FontWeight.w600 : null,
                      color: e.hasFocus
                          ? mdiStyle.focusedTabTextColor
                          : mdiStyle.unfocusedTabTextColor,
                    ),
                  ),
                ),
                _ButtonContainer(
                  onTap: e.close,
                  splashColor: Colors.red,
                  color: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(1),
                  child: Icon(
                    Icons.close_rounded,
                    size: 10,
                    color: e.hasFocus
                        ? mdiStyle.focusedTabTextColor
                        : mdiStyle.unfocusedTabTextColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      itemCount: list.length,
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      scrollController: controller.tabScrollController,
      onReorder: (oldIndex, newIndex) {
        controller.reorderTabs(oldIndex, newIndex);
      },
    );
  }
}

class _ButtonContainer extends StatelessWidget {
  final Widget child;
  final void Function()? onTap;
  final void Function()? onLongPress;
  final void Function()? onDoubleTap;
  final double? height;
  final double? width;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final double borderRadius;
  final BoxConstraints? constraints;
  final Color? color;
  final Color? disableColor;
  final Color? splashColor;
  final EdgeInsetsGeometry? margin;
  final bool enable;

  const _ButtonContainer({
    super.key,
    required this.child,
    this.onTap,
    this.height,
    this.width,
    this.alignment,
    this.padding,
    this.border,
    this.onLongPress,
    this.borderRadius = 4,
    this.constraints,
    this.color,
    this.disableColor,
    this.splashColor,
    this.margin,
    this.enable = true,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: enable
            ? (color ?? Colors.transparent)
            : (disableColor ?? Colors.transparent),
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enable ? onTap : null,
          onLongPress: enable ? onLongPress : null,
          onDoubleTap: enable ? onDoubleTap : null,
          splashColor:
              splashColor ??
              Theme.of(context).primaryColor.withValues(alpha: 0.5),
          hoverColor:
              splashColor ??
              Theme.of(context).primaryColor.withValues(alpha: 0.2),
          highlightColor:
              splashColor ??
              Theme.of(context).primaryColor.withValues(alpha: 0.4),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            padding: padding,
            alignment: alignment,
            constraints: constraints,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}
