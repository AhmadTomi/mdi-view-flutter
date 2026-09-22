part of '../mdi_view.dart';

/// Immutable configuration for window dimensions across the MDI surface.
///
/// Use [MdiDimensions.standard] for out-of-the-box fallback values (382 x 474).
/// Use [MdiDimensions.global] to configure app-wide dynamic defaults accessible
/// anywhere outside the controller:
/// ```dart
/// // Configure globally in main() or app setup:
/// MdiDimensions.global = const MdiDimensions(
///   defaultWidth: 500.0,
///   defaultHeight: 600.0,
///   defaultMinWidth: 350.0,
///   defaultMinHeight: 200.0,
/// );
///
/// // Read anywhere in your project without a controller:
/// final width = MdiDimensions.global.defaultWidth; // 500.0
/// ```
@immutable
class MdiDimensions {
  /// Default window width in logical pixels.
  final double defaultWidth;

  /// Default window height in logical pixels.
  final double defaultHeight;

  /// Default minimum window width in logical pixels.
  final double defaultMinWidth;

  /// Default minimum window height in logical pixels.
  final double defaultMinHeight;

  /// Standard fallback constants.
  static const double kStandardDefaultWidth = 382.0;
  static const double kStandardDefaultHeight = 474.0;
  static const double kStandardDefaultMinWidth = 382.0;
  static const double kStandardDefaultMinHeight = 119.0;

  /// Standard fallback configuration used when no dynamic dimensions are set.
  static const MdiDimensions standard = MdiDimensions();

  /// Global dynamic default dimensions.
  ///
  /// Can be set once at app launch or dynamically updated.
  /// Falls back to [standard] by default.
  static MdiDimensions global = standard;

  /// Convenience method to reconfigure [global] dimensions.
  static void configure({
    double? defaultWidth,
    double? defaultHeight,
    double? defaultMinWidth,
    double? defaultMinHeight,
  }) {
    global = global.copyWith(
      defaultWidth: defaultWidth,
      defaultHeight: defaultHeight,
      defaultMinWidth: defaultMinWidth,
      defaultMinHeight: defaultMinHeight,
    );
  }

  /// Resets [global] dimensions back to [standard] (useful for testing).
  static void resetGlobal() {
    global = standard;
  }

  const MdiDimensions({
    this.defaultWidth = kStandardDefaultWidth,
    this.defaultHeight = kStandardDefaultHeight,
    double? defaultMinWidth,
    this.defaultMinHeight = kStandardDefaultMinHeight,
  }) : defaultMinWidth = defaultMinWidth ?? defaultWidth;

  MdiDimensions copyWith({
    double? defaultWidth,
    double? defaultHeight,
    double? defaultMinWidth,
    double? defaultMinHeight,
  }) {
    return MdiDimensions(
      defaultWidth: defaultWidth ?? this.defaultWidth,
      defaultHeight: defaultHeight ?? this.defaultHeight,
      defaultMinWidth: defaultMinWidth ?? this.defaultMinWidth,
      defaultMinHeight: defaultMinHeight ?? this.defaultMinHeight,
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
