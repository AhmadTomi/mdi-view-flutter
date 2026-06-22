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

  // ── Geometry ──────────────────────────────────────────────────────────────

  final double minWidth;
  final double minHeight;
  final double currentWidth;
  final double currentHeight;
  final double x;
  final double y;

  // ── Arbitrary key/value payload ───────────────────────────────────────────

  final Map<String, dynamic> argument;

  // ── Grid defaults (configurable at the class level) ───────────────────────

  static const double defaultWidth = 382.0;
  static const double defaultHeight = 474.0;
  static const double defaultMinWidth = defaultWidth;

  /// Quarter-height grid unit used for keyboard movement and resize/drag
  /// snapping.
  ///
  /// `defaultHeight / 4` is `118.5` — a fractional logical pixel. Snapping
  /// to that grid lands `y`/`currentHeight` on a half-pixel boundary every
  /// other step, which is invisible on a perfect 2x Retina display (0.5
  /// logical px → 1 device px) but renders as a blurry, anti-aliased edge
  /// on a 1x display — a common setup when a Mac drives an external,
  /// non-Retina monitor. Rounded once here so every consumer shares a
  /// single whole-pixel grid value instead of recomputing the fraction.
  static const double defaultMinHeight = 119.0;

  // ── Constructor ───────────────────────────────────────────────────────────

  const ParameterWindow({
    this.id = 'Primary',
    required this.title,
    this.argument = const {},
    double? minWidth,
    double? minHeight,
    double? currentWidth,
    double? currentHeight,
    this.x = _kUnsetPosition,
    this.y = _kUnsetPosition,
  })  : minWidth = minWidth ?? defaultWidth,
        minHeight = minHeight ?? defaultMinHeight,
        currentWidth = currentWidth ?? defaultWidth,
        currentHeight = currentHeight ?? defaultHeight;

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Stable composite key used as a widget key and map key.
  String get tag => '$title.$id';

  bool get isPositionUnset => x == _kUnsetPosition || y == _kUnsetPosition;

  bool get isMaximize =>
      (argument[MdiArgumentKeys.isMaximize] ?? '0') == '1';

  double get cornerX => x + currentWidth;
  double get cornerY => y + currentHeight;

  // ── Grid helpers ──────────────────────────────────────────────────────────

  static int getWidthScale(double width) {
    final result = (width + 6) ~/ defaultWidth;
    return result < 1 ? 1 : result;
  }

  static int getHeightScale(double height) {
    final result = (height + 6) ~/ defaultHeight;
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
      minHeight: minHeight ?? this.minHeight,
      minWidth: minWidth ?? this.minWidth,
      currentWidth: currentWidth ?? this.currentWidth,
      currentHeight: currentHeight ?? this.currentHeight,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  // ── Equality / hashing ────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ParameterWindow) return false;
    return id == other.id &&
        title == other.title &&
        _mapsEqual(argument, other.argument) &&
        minWidth == other.minWidth &&
        minHeight == other.minHeight &&
        currentWidth == other.currentWidth &&
        currentHeight == other.currentHeight &&
        x == other.x &&
        y == other.y;
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