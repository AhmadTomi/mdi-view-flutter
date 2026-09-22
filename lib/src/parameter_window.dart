part of '../mdi_view.dart';

/// Sentinel value indicating an unset position (will be auto-centered on open).
const double _kUnsetPosition = -1.0;

/// Immutable descriptor for an MDI window's identity, size, and position.
///
/// All mutation returns a new instance via [copyWith] — the controller owns
/// the mutable runtime state; [ParameterWindow] is a pure value object.
@immutable
class ParameterWindow {
  // ── Identity ──────────────────────────────────────────────────────────────

  final String id;
  final String title;

  // ── Geometry (internal storage) ───────────────────────────────────────────

  final double? _minWidth;
  final double? _minHeight;
  final double? _currentWidth;
  final double? _currentHeight;
  final double x;
  final double y;

  /// Optional per-window dimensions configuration.
  /// When omitted, falls back to [MdiDimensions.global] (which defaults to [MdiDimensions.standard]).
  final MdiDimensions? dimensions;

  // ── Geometry (resolved getters) ───────────────────────────────────────────

  double get minWidth =>
      _minWidth ?? dimensions?.defaultMinWidth ?? MdiDimensions.minWidth;
  double get minHeight =>
      _minHeight ?? dimensions?.defaultMinHeight ?? MdiDimensions.minHeight;
  double get currentWidth =>
      _currentWidth ?? dimensions?.defaultWidth ?? MdiDimensions.width;
  double get currentHeight =>
      _currentHeight ?? dimensions?.defaultHeight ?? MdiDimensions.height;

  // ── Arbitrary key/value payload ───────────────────────────────────────────

  final Map<String, dynamic> argument;

  // ── Legacy defaults (deprecated: use MdiDimensions) ───────────────────────

  @Deprecated(
    'Use MdiDimensions.width or MdiDimensions.defaults.defaultWidth instead. '
    'Will be removed in a future major version.',
  )
  static double get defaultWidth => MdiDimensions.width;

  @Deprecated(
    'Use MdiDimensions.height or MdiDimensions.defaults.defaultHeight instead. '
    'Will be removed in a future major version.',
  )
  static double get defaultHeight => MdiDimensions.height;

  @Deprecated(
    'Use MdiDimensions.minWidth or MdiDimensions.defaults.defaultMinWidth instead. '
    'Will be removed in a future major version.',
  )
  static double get defaultMinWidth => MdiDimensions.minWidth;

  @Deprecated(
    'Use MdiDimensions.minHeight or MdiDimensions.defaults.defaultMinHeight instead. '
    'Will be removed in a future major version.',
  )
  static double get defaultMinHeight => MdiDimensions.minHeight;

  // ── Constructor ───────────────────────────────────────────────────────────

  const ParameterWindow({
    this.id = 'Primary.mdi',
    required this.title,
    this.argument = const {},
    this.dimensions,
    double? minWidth,
    double? minHeight,
    double? currentWidth,
    double? currentHeight,
    this.x = _kUnsetPosition,
    this.y = _kUnsetPosition,
  })  : _minWidth = minWidth,
        _minHeight = minHeight,
        _currentWidth = currentWidth,
        _currentHeight = currentHeight;

  /// Resolves any unspecified dimension fields against [parentDimensions].
  ParameterWindow resolveWith(MdiDimensions parentDimensions) {
    return copyWith(
      dimensions: dimensions ?? parentDimensions,
      minWidth: _minWidth ?? parentDimensions.defaultMinWidth,
      minHeight: _minHeight ?? parentDimensions.defaultMinHeight,
      currentWidth: _currentWidth ?? parentDimensions.defaultWidth,
      currentHeight: _currentHeight ?? parentDimensions.defaultHeight,
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Stable composite key used as a widget key and map key.
  String get tag => '$title.$id';

  bool get isPositionUnset => x == _kUnsetPosition || y == _kUnsetPosition;

  bool get isMaximize =>
      (argument[MdiArgumentKeys.isMaximize] ?? '0') == '1';

  double get cornerX => x + currentWidth;
  double get cornerY => y + currentHeight;

  // ── Grid helpers ──────────────────────────────────────────────────────────

  static int getWidthScale(double width, [MdiDimensions? dimensions]) {
    final dWidth = dimensions?.defaultWidth ?? MdiDimensions.width;
    final result = (width + 6) ~/ dWidth;
    return result < 1 ? 1 : result;
  }

  static int getHeightScale(double height, [MdiDimensions? dimensions]) {
    final dHeight = dimensions?.defaultHeight ?? MdiDimensions.height;
    final result = (height + 6) ~/ dHeight;
    return result < 1 ? 0 : result;
  }

  // ── Mutation helpers (return new instances) ───────────────────────────────

  ParameterWindow withMaximize(bool value) => copyWith(
    argument: {...argument, MdiArgumentKeys.isMaximize: value ? '1' : '0'},
  );

  ParameterWindow withArgument(Map<String, dynamic> extra) =>
      copyWith(argument: {...argument, ...extra});

  ParameterWindow withPosition({required double posX, required double posY}) =>
      copyWith(x: posX, y: posY);

  ParameterWindow withSize({
    required double width,
    required double height,
  }) =>
      copyWith(currentWidth: width, currentHeight: height);

  // ── copyWith ──────────────────────────────────────────────────────────────

  ParameterWindow copyWith({
    String? id,
    String? title,
    Map<String, dynamic>? argument,
    MdiDimensions? dimensions,
    double? minHeight,
    double? minWidth,
    double? currentWidth,
    double? currentHeight,
    double? x,
    double? y,
  }) {
    return ParameterWindow(
      id: id ?? this.id,
      title: title ?? this.title,
      argument: argument ?? this.argument,
      dimensions: dimensions ?? this.dimensions,
      minHeight: minHeight ?? _minHeight,
      minWidth: minWidth ?? _minWidth,
      currentWidth: currentWidth ?? _currentWidth,
      currentHeight: currentHeight ?? _currentHeight,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  // ── Equality / hashing ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    // Toggle this variable to enable or disable all debug prints for this function
    bool enableDebugPrint = false;

    // Local helper function to keep the checks clean and handle the prefix
    void logDebug(String message) {
      if (enableDebugPrint) {
        print('Debug == [ParameterWindow]: $message');
      }
    }

    if (other is! ParameterWindow) {
      logDebug('other is not a ParameterWindow (is ${other.runtimeType})');
      return false;
    }

    // We use a flag so we can check and print ALL differences at once
    bool isEqual = true;

    if (title != other.title) {
      logDebug('title mismatch -> this: $title, other: ${other.title}');
      isEqual = false;
    }
    if (!_mapsEqual(argument, other.argument)) {
      logDebug('argument mismatch -> this: $argument, other: ${other.argument}');
      isEqual = false;
    }
    if (!_mapsEqual(argument, other.argument)) {
      logDebug('argument mismatch -> this: $argument, other: ${other.argument}');
      isEqual = false;
    }
    if (currentWidth != other.currentWidth) {
      logDebug('currentWidth mismatch -> this: $currentWidth, other: ${other.currentWidth}');
      isEqual = false;
    }
    if (currentHeight != other.currentHeight) {
      logDebug('currentHeight mismatch -> this: $currentHeight, other: ${other.currentHeight}');
      isEqual = false;
    }
    if (x != other.x) {
      logDebug('x mismatch -> this: $x, other: ${other.x}');
      isEqual = false;
    }
    if (y != other.y) {
      logDebug('y mismatch -> this: $y, other: ${other.y}');
      isEqual = false;
    }

    return isEqual;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    // Produce an order-independent hash for the argument map.
    Object.hashAllUnordered(
      argument.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    minWidth,
    minHeight,
    currentWidth,
    currentHeight,
    x,
    y,
  ]);

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Shallow key-value equality for [argument] maps.
  ///
  /// Values are compared with `==`, so nested collections are compared by
  /// identity unless they also override `==`.  This is sufficient for the
  /// primitive payloads [ParameterWindow] carries in practice.
  static bool _mapsEqual(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
      ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'argument': argument,
    'minWidth': minWidth,
    'minHeight': minHeight,
    'currentWidth': currentWidth,
    'currentHeight': currentHeight,
    'x': x,
    'y': y,
  };

  factory ParameterWindow.fromJson(Map<String, dynamic> json) {
    return ParameterWindow(
      id: json['id'] as String? ?? 'Primary',
      title: json['title'] as String,
      argument: (json['argument'] as Map?)?.cast<String, dynamic>() ?? {},
      minWidth: (json['minWidth'] as num?)?.toDouble(),
      minHeight: (json['minHeight'] as num?)?.toDouble(),
      currentWidth: (json['currentWidth'] as num?)?.toDouble(),
      currentHeight: (json['currentHeight'] as num?)?.toDouble(),
      x: (json['x'] as num?)?.toDouble() ?? _kUnsetPosition,
      y: (json['y'] as num?)?.toDouble() ?? _kUnsetPosition,
    );
  }

  @override
  String toString() =>
      'ParameterWindow(tag: $tag, x: $x, y: $y, '
          'w: $currentWidth, h: $currentHeight)';
}

/// Well-known keys stored inside [ParameterWindow.argument].
abstract final class MdiArgumentKeys {
  static const String isMaximize = 'isMaximize';
}