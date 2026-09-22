part of '../mdi_view.dart';

/// Immutable configuration for window dimensions across the MDI surface.
///
/// Use [MdiDimensions.defaults] for the out-of-the-box fallback values (382 x 474).
/// Access or modify active dimensions directly at the class level from anywhere:
/// ```dart
/// // Read anywhere in your project without a controller or context:
/// final h = MdiDimensions.height; // 474.0
/// final w = MdiDimensions.width;  // 382.0
///
/// // Update anywhere:
/// MdiDimensions.height = 600.0;
/// MdiDimensions.width = 500.0;
///
/// // Or set an entire dimensions profile:
/// MdiDimensions.global = const MdiDimensions(width: 500, height: 600);
/// ```
@immutable
class MdiDimensions {
  // ── Private standard fallback values ───────────────────────────────────────

  static const double _kDefaultWidth = 382.0;
  static const double _kDefaultHeight = 474.0;
  static const double _kDefaultMinWidth = 382.0;
  static const double _kDefaultMinHeight = 119.0;

  // ── Standard presets ───────────────────────────────────────────────────────

  /// Standard fallback configuration used when no custom dimensions are set.
  static const MdiDimensions defaults = MdiDimensions();

  /// Deprecated alias for [defaults].
  @Deprecated('Use MdiDimensions.defaults instead. Will be removed in a future release.')
  static const MdiDimensions standard = defaults;

  // ── Global dynamic state ───────────────────────────────────────────────────

  /// Global active dimensions profile.
  ///
  /// Can be set once at app launch or dynamically updated.
  /// Defaults to [defaults].
  static MdiDimensions global = defaults;

  // ── Direct static accessors ────────────────────────────────────────────────

  /// Active default window width in logical pixels.
  static double get width => global.defaultWidth;
  static set width(double value) => global = global.copyWith(defaultWidth: value);

  /// Active default window height in logical pixels.
  static double get height => global.defaultHeight;
  static set height(double value) => global = global.copyWith(defaultHeight: value);

  /// Active default minimum window width in logical pixels.
  static double get minWidth => global.defaultMinWidth;
  static set minWidth(double value) => global = global.copyWith(defaultMinWidth: value);

  /// Active default minimum window height in logical pixels.
  static double get minHeight => global.defaultMinHeight;
  static set minHeight(double value) => global = global.copyWith(defaultMinHeight: value);

  /// Convenience method to reconfigure active dimensions.
  static void configure({
    double? width,
    double? height,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
    double? defaultMinWidth,
    double? defaultMinHeight,
  }) {
    global = global.copyWith(
      defaultWidth: width ?? defaultWidth,
      defaultHeight: height ?? defaultHeight,
      defaultMinWidth: minWidth ?? defaultMinWidth,
      defaultMinHeight: minHeight ?? defaultMinHeight,
    );
  }

  /// Resets active dimensions back to [defaults] (useful for testing).
  static void resetGlobal() {
    global = defaults;
  }

  // ── Instance fields ───────────────────────────────────────────────────────

  /// Window width in logical pixels.
  final double defaultWidth;

  /// Window height in logical pixels.
  final double defaultHeight;

  /// Minimum window width in logical pixels.
  final double defaultMinWidth;

  /// Minimum window height in logical pixels.
  final double defaultMinHeight;

  // ── Constructor ───────────────────────────────────────────────────────────

  const MdiDimensions({
    double? width,
    double? height,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
    double? defaultMinWidth,
    double? defaultMinHeight,
  })  : defaultWidth = width ?? defaultWidth ?? _kDefaultWidth,
        defaultHeight = height ?? defaultHeight ?? _kDefaultHeight,
        defaultMinWidth = minWidth ?? defaultMinWidth ?? width ?? defaultWidth ?? _kDefaultMinWidth,
        defaultMinHeight = minHeight ?? defaultMinHeight ?? _kDefaultMinHeight;

  // ── copyWith ──────────────────────────────────────────────────────────────

  MdiDimensions copyWith({
    double? width,
    double? height,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
    double? defaultMinWidth,
    double? defaultMinHeight,
  }) {
    return MdiDimensions(
      defaultWidth: width ?? defaultWidth ?? this.defaultWidth,
      defaultHeight: height ?? defaultHeight ?? this.defaultHeight,
      defaultMinWidth: minWidth ?? defaultMinWidth ?? this.defaultMinWidth,
      defaultMinHeight: minHeight ?? defaultMinHeight ?? this.defaultMinHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MdiDimensions &&
        other.defaultWidth == defaultWidth &&
        other.defaultHeight == defaultHeight &&
        other.defaultMinWidth == defaultMinWidth &&
        other.defaultMinHeight == defaultMinHeight;
  }

  @override
  int get hashCode => Object.hash(
        defaultWidth,
        defaultHeight,
        defaultMinWidth,
        defaultMinHeight,
      );

  @override
  String toString() =>
      'MdiDimensions(width: $defaultWidth, height: $defaultHeight, minWidth: $defaultMinWidth, minHeight: $defaultMinHeight)';
}
