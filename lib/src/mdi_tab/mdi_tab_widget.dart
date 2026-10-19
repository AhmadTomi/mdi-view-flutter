part of 'mdi_tab.dart';

// ── MdiTabWidget ──────────────────────────────────────────────────────────────

/// The horizontal tab bar sitting at the top of the MDI surface.
///
/// Responsibilities:
///   • Renders a reorderable list of window tabs.
///   • Shows left/right scroll arrows when tabs overflow.
///   • Provides a maximize/restore toggle button.
class MdiTabWidget extends StatefulWidget {
  final MdiController mdiController;

  const MdiTabWidget(this.mdiController, {super.key});

  @override
  State<MdiTabWidget> createState() => _MdiTabWidgetState();
}

class _MdiTabWidgetState extends State<MdiTabWidget> {
  late final MdiTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = widget.mdiController.tabMenuController;
    _tabController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _tabController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final style = MdiStyleProvider.of(context);

    return Container(
      color: style.tabBackgroundColor,
      height: 24,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(child: _TabList(mdiController: widget.mdiController)),
          _TabToolbar(mdiController: widget.mdiController),
        ],
      ),
    );
  }
}

// ── _TabList ──────────────────────────────────────────────────────────────────

class _TabList extends StatefulWidget {
  final MdiController mdiController;

  const _TabList({required this.mdiController});

  @override
  State<_TabList> createState() => _TabListState();
}

class _TabListState extends State<_TabList> {
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _tabKeys = {};

  Offset? _pointerDownGlobal;
  Offset? _pointerDownLocal;
  int? _pointerDownIndex;
  bool _hasMovedPastSlop = false;
  static const double _kDragSlop = 4.0;

  @override
  void initState() {
    super.initState();
    widget.mdiController.tabMenuController.addListener(_onTabControllerChanged);
  }

  @override
  void didUpdateWidget(_TabList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mdiController != widget.mdiController) {
      oldWidget.mdiController.tabMenuController.removeListener(_onTabControllerChanged);
      widget.mdiController.tabMenuController.addListener(_onTabControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.mdiController.tabMenuController.removeListener(_onTabControllerChanged);
    super.dispose();
  }

  void _onTabControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onTabPointerDown(int index, PointerDownEvent event) {
    if (event.buttons != kPrimaryMouseButton) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _pointerDownGlobal = event.position;
    _pointerDownLocal = box.globalToLocal(event.position);
    _pointerDownIndex = index;
    _hasMovedPastSlop = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final tabCtrl = widget.mdiController.tabMenuController;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(event.position);

    if (_pointerDownIndex != null && !_hasMovedPastSlop && _pointerDownGlobal != null) {
      final dist = (event.position - _pointerDownGlobal!).distance;
      if (dist >= _kDragSlop) {
        _hasMovedPastSlop = true;
        _startDrag(box, _pointerDownIndex!, _pointerDownLocal!);
      }
    }

    if (tabCtrl.isDraggingTab) {
      tabCtrl.updateTabDrag(
        pointerLocalX: localPos.dx,
        scrollOffset: tabCtrl.tabScrollController.hasClients
            ? tabCtrl.tabScrollController.offset
            : 0.0,
      );
      tabCtrl.checkEdgeAutoScroll(localPos.dx, box.size.width);
    }
  }

  void _startDrag(RenderBox viewportBox, int index, Offset pointerLocal) {
    final tabCtrl = widget.mdiController.tabMenuController;
    final tabs = tabCtrl.tabControllers;
    if (index >= tabs.length) return;

    final tabWidths = <double>[];
    double draggedTabLeftInViewport = 0.0;

    for (int i = 0; i < tabs.length; i++) {
      final key = _tabKeys[tabs[i].tag];
      final itemBox = key?.currentContext?.findRenderObject() as RenderBox?;
      final w = itemBox?.hasSize == true
          ? itemBox!.size.width
          : (tabs[i].hasFocus ? 120.0 : 60.0);
      tabWidths.add(w);

      if (i == index && itemBox != null && itemBox.hasSize) {
        final itemLocalToViewport =
            viewportBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
        draggedTabLeftInViewport = itemLocalToViewport.dx;
      }
    }

    final draggedWidth = tabWidths[index];
    final grabOffset = (pointerLocal.dx - draggedTabLeftInViewport).clamp(0.0, draggedWidth);

    tabCtrl.startTabDrag(
      index: index,
      pointerLocalX: pointerLocal.dx,
      grabOffsetX: grabOffset,
      tabWidth: draggedWidth,
      tabWidths: tabWidths,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerDownIndex = null;
    _pointerDownGlobal = null;
    _pointerDownLocal = null;
    _hasMovedPastSlop = false;
    final tabCtrl = widget.mdiController.tabMenuController;
    if (tabCtrl.isDraggingTab) {
      tabCtrl.endTabDrag();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDownIndex = null;
    _pointerDownGlobal = null;
    _pointerDownLocal = null;
    _hasMovedPastSlop = false;
    final tabCtrl = widget.mdiController.tabMenuController;
    if (tabCtrl.isDraggingTab) {
      tabCtrl.cancelTabDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = MdiStyleProvider.of(context);
    final tabCtrl = widget.mdiController.tabMenuController;
    final tabs = tabCtrl.tabControllers;

    // Prune stale keys and populate active keys
    final activeTags = tabs.map((c) => c.tag).toSet();
    _tabKeys.removeWhere((tag, _) => !activeTags.contains(tag));
    for (final ctrl in tabs) {
      _tabKeys.putIfAbsent(ctrl.tag, () => GlobalKey());
    }

    ResizeableWindowController? draggedCtrl;
    if (tabCtrl.isDraggingTab &&
        tabCtrl.draggedTabIndex != null &&
        tabCtrl.draggedTabIndex! < tabs.length) {
      draggedCtrl = tabs[tabCtrl.draggedTabIndex!];
    }

    return Listener(
      key: _viewportKey,
      behavior: HitTestBehavior.translucent,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            controller: tabCtrl.tabScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++) ...[
                  if (tabCtrl.isDraggingTab &&
                      tabCtrl.dropTargetIndex == i &&
                      i != tabCtrl.draggedTabIndex)
                    _buildPlaceholder(tabCtrl.draggedTabWidth, style),
                  if (tabCtrl.isDraggingTab && i == tabCtrl.draggedTabIndex)
                    _buildPlaceholder(tabCtrl.draggedTabWidth, style)
                  else
                    Listener(
                      onPointerDown: (e) => _onTabPointerDown(i, e),
                      child: _TabItem(
                        key: _tabKeys[tabs[i].tag],
                        controller: tabs[i],
                        style: style,
                      ),
                    ),
                ],
                if (tabCtrl.isDraggingTab &&
                    tabCtrl.dropTargetIndex != null &&
                    tabCtrl.dropTargetIndex! >= tabs.length)
                  _buildPlaceholder(tabCtrl.draggedTabWidth, style),
              ],
            ),
          ),
          if (tabCtrl.isDraggingTab && draggedCtrl != null)
            Positioned(
              left: tabCtrl.dragPointerLocalX - tabCtrl.dragGrabOffsetX,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.transparent,
                  child: _TabItem(
                    controller: draggedCtrl,
                    style: style,
                    isFloating: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(double width, MdiStyleConfiguration style) {
    return Container(
      width: width,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: style.tabBackgroundColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: style.focusedBorderColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
    );
  }
}

// ── _TabItem ──────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final ResizeableWindowController controller;
  final MdiStyleConfiguration style;
  final bool isFloating;

  const _TabItem({
    super.key,
    required this.controller,
    required this.style,
    this.isFloating = false,
  });

  @override
  Widget build(BuildContext context) {
    final focused = controller.hasFocus;

    return _TapTarget(
      color: (focused || isFloating)
          ? style.focusedTabMenuColor
          : style.unfocusedTabMenuColor,
      borderRadius: 2,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      width: focused ? null : style.tabMenuMinWidth,
      splashColor: style.tabSplashColor,
      margin: EdgeInsets.zero,
      onTap: isFloating ? null : controller.requestFocus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: focused ? 0 : 1,
            child: Text(
              controller.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: (focused || isFloating) ? FontWeight.w600 : null,
                color: (focused || isFloating)
                    ? style.focusedTabTextColor
                    : style.unfocusedTabTextColor,
              ),
            ),
          ),
          _TapTarget(
            onTap: isFloating ? null : controller.close,
            splashColor: Colors.red,
            color: Colors.red.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(1),
            child: Icon(
              Icons.close_rounded,
              size: 10,
              color: (focused || isFloating)
                  ? style.focusedTabTextColor
                  : style.unfocusedTabTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TabToolbar ───────────────────────────────────────────────────────────────

class _TabToolbar extends StatelessWidget {
  final MdiController mdiController;

  const _TabToolbar({required this.mdiController});

  @override
  Widget build(BuildContext context) {
    final style = MdiStyleProvider.of(context);
    final tab = mdiController.tabMenuController;

    return Row(
      children: [
        _kDivider,
        if (tab.showTabNavButton) ...[
          _ScrollButton(
            enabled: tab.showLeftButton,
            icon: Icons.keyboard_arrow_left_rounded,
            onTap: tab.scrollLeft,
            style: style,
          ),
          _ScrollButton(
            enabled: tab.showRightButton,
            icon: Icons.keyboard_arrow_right_rounded,
            onTap: tab.scrollRight,
            style: style,
          ),
        ],
        _kDivider,
        _TapTarget(
          onTap: mdiController.toggleMaximize,
          borderRadius: 0,
          color: style.tabBackgroundColor.withValues(alpha: 0.4),
          splashColor: style.tabSplashColor,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Icon(
            mdiController.isMaximize
                ? Icons.grid_view_rounded
                : Icons.fit_screen_rounded,
            size: 15,
            opticalSize: 60,
            color: style.unfocusedTabTextColor,
          ),
        ),
      ],
    );
  }
}

class _ScrollButton extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;
  final MdiStyleConfiguration style;

  const _ScrollButton({
    required this.enabled,
    required this.icon,
    required this.onTap,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return _TapTarget(
      enable: enabled,
      onTap: onTap,
      borderRadius: 0,
      color: style.focusedTabMenuColor.withValues(alpha: 0.4),
      splashColor: style.tabSplashColor,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Icon(icon, size: 15, color: style.unfocusedTabTextColor),
    );
  }
}

const Widget _kDivider = SizedBox(
  height: 32,
  width: 0.6,
  child: VerticalDivider(thickness: 0.6),
);

// ── _TapTarget ────────────────────────────────────────────────────────────────

/// Lightweight tappable container backed by [Material] + [InkWell] so
/// that ink splash colours are honoured correctly.
class _TapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final Color? splashColor;
  final EdgeInsetsGeometry? margin;
  final bool enable;

  const _TapTarget({
    required this.child,
    this.onTap,
    this.width,
    this.padding,
    this.borderRadius = 4,
    this.color,
    this.splashColor,
    this.margin,
    this.enable = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        enable ? (color ?? Colors.transparent) : Colors.transparent;
    final effectiveSplash =
        splashColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.5);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enable ? onTap : null,
          splashColor: effectiveSplash,
          hoverColor: effectiveSplash.withValues(alpha: 0.2),
          highlightColor: effectiveSplash.withValues(alpha: 0.4),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            padding: padding,
            width: width,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
