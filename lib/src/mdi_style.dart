part of '../mdi_view.dart';

// ── Style provider ────────────────────────────────────────────────────────────

/// Propagates [MdiStyleConfiguration] down the widget tree without
/// re-building descendants unless the configuration actually changes.
class MdiStyleProvider extends InheritedWidget {
  final MdiStyleConfiguration style;

  const MdiStyleProvider({
    super.key,
    required this.style,
    required super.child,
  });

  /// Returns the nearest [MdiStyleConfiguration], falling back to
  /// [MdiStyleConfiguration.defaults] when no ancestor is present.
  static MdiStyleConfiguration of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MdiStyleProvider>()
            ?.style ??
        MdiStyleConfiguration.defaults;
  }

  @override
  bool updateShouldNotify(MdiStyleProvider oldWidget) =>
      oldWidget.style != style;
}

// ── Style configuration ───────────────────────────────────────────────────────

/// Immutable theming contract for the MDI surface and its windows.
///
/// All colour parameters are optional; pass only what you want to override —
/// the remaining values are sourced from [MdiStyleConfiguration.defaults].
@immutable
class MdiStyleConfiguration {
  // ── Border & chrome ───────────────────────────────────────────────────────
  final Color focusedBorderColor;
  final Color unfocusedBorderColor;
  final Color maximizedBorderColor;
  final int borderWidth;
  final int borderRadius;

  // ── Surface colours ───────────────────────────────────────────────────────
  final Color mdiBackgroundColor;
  final Color windowBackgroundColor;
  final Color unfocusBlockerColor;

  // ── Tab bar ───────────────────────────────────────────────────────────────
  final Color tabBackgroundColor;
  final Color tabSplashColor;
  final Color focusedTabTextColor;
  final Color unfocusedTabTextColor;
  final Color focusedTabMenuColor;
  final Color unfocusedTabMenuColor;
  final double tabMenuMinWidth;

  // ── Layout ────────────────────────────────────────────────────────────────
  final int gap;

  // ── Factory defaults ──────────────────────────────────────────────────────

  /// Pre-built configuration used when no [MdiStyleProvider] is in scope.
  static final MdiStyleConfiguration defaults = MdiStyleConfiguration();

  const MdiStyleConfiguration._raw({
    required this.gap,
    required this.focusedBorderColor,
    required this.unfocusedBorderColor,
    required this.maximizedBorderColor,
    required this.windowBackgroundColor,
    required this.mdiBackgroundColor,
    required this.tabMenuMinWidth,
    required this.focusedTabTextColor,
    required this.unfocusedTabTextColor,
    required this.focusedTabMenuColor,
    required this.unfocusedTabMenuColor,
    required this.tabBackgroundColor,
    required this.tabSplashColor,
    required this.unfocusBlockerColor,
    required this.borderWidth,
    required this.borderRadius,
  });

  factory MdiStyleConfiguration({
    int gap = 1,
    Color focusedBorderColor = Colors.blue,
    Color unfocusedBorderColor = Colors.blueGrey,
    Color maximizedBorderColor = Colors.blueGrey,
    Color windowBackgroundColor = Colors.white,
    Color mdiBackgroundColor = Colors.grey,
    double tabMenuMinWidth = 40,
    Color? focusedTabTextColor,
    Color? unfocusedTabTextColor,
    Color? focusedTabMenuColor,
    Color? unfocusedTabMenuColor,
    Color? tabBackgroundColor,
    Color? tabSplashColor,
    Color? unfocusBlockerColor,
    int borderWidth = 1,
    int borderRadius = 4,
  }) {
    return MdiStyleConfiguration._raw(
      gap: gap,
      focusedBorderColor: focusedBorderColor,
      unfocusedBorderColor: unfocusedBorderColor,
      maximizedBorderColor: maximizedBorderColor,
      windowBackgroundColor: windowBackgroundColor,
      mdiBackgroundColor: mdiBackgroundColor,
      tabMenuMinWidth: tabMenuMinWidth,
      focusedTabTextColor: focusedTabTextColor ?? Colors.white,
      unfocusedTabTextColor: unfocusedTabTextColor ?? Colors.white70,
      focusedTabMenuColor: focusedTabMenuColor ?? Colors.blue,
      unfocusedTabMenuColor: unfocusedTabMenuColor ?? Colors.blue.shade700,
      tabBackgroundColor: tabBackgroundColor ?? Colors.blue.shade700,
      tabSplashColor: tabSplashColor ?? Colors.blue.shade400,
      unfocusBlockerColor:
          unfocusBlockerColor ?? Colors.grey.withValues(alpha: 0.2),
      borderWidth: borderWidth,
      borderRadius: borderRadius,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  MdiStyleConfiguration copyWith({
    int? gap,
    Color? focusedBorderColor,
    Color? unfocusedBorderColor,
    Color? maximizedBorderColor,
    Color? windowBackgroundColor,
    Color? mdiBackgroundColor,
    double? tabMenuMinWidth,
    Color? focusedTabTextColor,
    Color? unfocusedTabTextColor,
    Color? focusedTabMenuColor,
    Color? unfocusedTabMenuColor,
    Color? tabBackgroundColor,
    Color? tabSplashColor,
    Color? unfocusBlockerColor,
    int? borderWidth,
    int? borderRadius,
  }) =>
      MdiStyleConfiguration._raw(
        gap: gap ?? this.gap,
        focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
        unfocusedBorderColor:
            unfocusedBorderColor ?? this.unfocusedBorderColor,
        maximizedBorderColor:
            maximizedBorderColor ?? this.maximizedBorderColor,
        windowBackgroundColor:
            windowBackgroundColor ?? this.windowBackgroundColor,
        mdiBackgroundColor: mdiBackgroundColor ?? this.mdiBackgroundColor,
        tabMenuMinWidth: tabMenuMinWidth ?? this.tabMenuMinWidth,
        focusedTabTextColor: focusedTabTextColor ?? this.focusedTabTextColor,
        unfocusedTabTextColor:
            unfocusedTabTextColor ?? this.unfocusedTabTextColor,
        focusedTabMenuColor: focusedTabMenuColor ?? this.focusedTabMenuColor,
        unfocusedTabMenuColor:
            unfocusedTabMenuColor ?? this.unfocusedTabMenuColor,
        tabBackgroundColor: tabBackgroundColor ?? this.tabBackgroundColor,
        tabSplashColor: tabSplashColor ?? this.tabSplashColor,
        unfocusBlockerColor: unfocusBlockerColor ?? this.unfocusBlockerColor,
        borderWidth: borderWidth ?? this.borderWidth,
        borderRadius: borderRadius ?? this.borderRadius,
      );

  // ── Equality / hashing ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MdiStyleConfiguration) return false;
    return gap == other.gap &&
        focusedBorderColor == other.focusedBorderColor &&
        unfocusedBorderColor == other.unfocusedBorderColor &&
        maximizedBorderColor == other.maximizedBorderColor &&
        windowBackgroundColor == other.windowBackgroundColor &&
        mdiBackgroundColor == other.mdiBackgroundColor &&
        tabMenuMinWidth == other.tabMenuMinWidth &&
        focusedTabTextColor == other.focusedTabTextColor &&
        unfocusedTabTextColor == other.unfocusedTabTextColor &&
        focusedTabMenuColor == other.focusedTabMenuColor &&
        unfocusedTabMenuColor == other.unfocusedTabMenuColor &&
        tabBackgroundColor == other.tabBackgroundColor &&
        tabSplashColor == other.tabSplashColor &&
        unfocusBlockerColor == other.unfocusBlockerColor &&
        borderWidth == other.borderWidth &&
        borderRadius == other.borderRadius;
  }

  @override
  int get hashCode => Object.hashAll([
        gap,
        focusedBorderColor,
        unfocusedBorderColor,
        maximizedBorderColor,
        windowBackgroundColor,
        mdiBackgroundColor,
        tabMenuMinWidth,
        focusedTabTextColor,
        unfocusedTabTextColor,
        focusedTabMenuColor,
        unfocusedTabMenuColor,
        tabBackgroundColor,
        tabSplashColor,
        unfocusBlockerColor,
        borderWidth,
        borderRadius,
      ]);
}
