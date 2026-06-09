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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.tabScrollCheck();
    });

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

class _TabList extends StatelessWidget {
  final MdiController mdiController;

  const _TabList({required this.mdiController});

  @override
  Widget build(BuildContext context) {
    final style = MdiStyleProvider.of(context);
    final tabs = mdiController.tabMenuController.tabControllers;

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      scrollController: mdiController.tabMenuController.tabScrollController,
      itemCount: tabs.length,
      onReorder: mdiController.tabMenuController.reorderTabs,
      itemBuilder: (_, index) {
        final ctrl = tabs[index];
        return ReorderableDragStartListener(
          key: ValueKey(ctrl.tag),
          index: index,
          child: _TabItem(
            key: ValueKey(ctrl.tag),
            controller: ctrl,
            style: style,
          ),
        );
      },
    );
  }
}

// ── _TabItem ──────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final ResizeableWindowController controller;
  final MdiStyleConfiguration style;

  const _TabItem({
    super.key,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final focused = controller.hasFocus;

    return _TapTarget(
      color: focused ? style.focusedTabMenuColor : style.unfocusedTabMenuColor,
      borderRadius: 2,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      width: focused ? null : style.tabMenuMinWidth,
      splashColor: style.tabSplashColor,
      margin: EdgeInsets.zero,
      onTap: controller.requestFocus,
      child: Row(
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
                fontWeight: focused ? FontWeight.w600 : null,
                color: focused
                    ? style.focusedTabTextColor
                    : style.unfocusedTabTextColor,
              ),
            ),
          ),
          _TapTarget(
            onTap: controller.close,
            splashColor: Colors.red,
            color: Colors.red.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(1),
            child: Icon(
              Icons.close_rounded,
              size: 10,
              color: focused
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
///
/// Replaces the old `_ButtonContainer` — identical API, cleaner internals.
class _TapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final double? height;
  final double? width;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final double borderRadius;
  final BoxConstraints? constraints;
  final Color? color;
  final Color? disabledColor;
  final Color? splashColor;
  final EdgeInsetsGeometry? margin;
  final bool enable;

  const _TapTarget({
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
    this.disabledColor,
    this.splashColor,
    this.margin,
    this.enable = true,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        enable ? (color ?? Colors.transparent) : (disabledColor ?? Colors.transparent);
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
          onLongPress: enable ? onLongPress : null,
          onDoubleTap: enable ? onDoubleTap : null,
          splashColor: effectiveSplash,
          hoverColor: effectiveSplash.withValues(alpha: 0.2),
          highlightColor: effectiveSplash.withValues(alpha: 0.4),
          splashFactory: NoSplash.splashFactory,
          child: Container(
            padding: padding,
            alignment: alignment,
            constraints: constraints,
            width: width,
            height: height,
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
