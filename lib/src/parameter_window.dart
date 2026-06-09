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

  /// Number of column units a window occupies by default.
  static double get defaultMinWidth => defaultWidth;

  /// Number of row units a window occupies by default (¼ of full height).
  static double get defaultMinHeight => defaultHeight / 4.0;

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
  })  : minWidth = minWidth ?? defaultWidth,        // ignore: prefer_initializing_formals
        minHeight = minHeight ?? 118.5,             // defaultHeight / 4
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
        argument.toString() == other.argument.toString() &&
        minWidth == other.minWidth &&
        minHeight == other.minHeight &&
        currentWidth == other.currentWidth &&
        currentHeight == other.currentHeight &&
        x == other.x &&
        y == other.y;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        argument.toString(),
        minWidth,
        minHeight,
        currentWidth,
        currentHeight,
        x,
        y,
      );

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
