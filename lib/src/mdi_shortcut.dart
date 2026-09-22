part of '../mdi_view.dart';

const Object _kUndefinedShortcut = Object();

/// Configuration for keyboard shortcuts supported by [MdiManager] and [MdiController].
///
/// Use [MdiShortcutConfiguration.defaults] for the standard out-of-the-box bindings,
/// or [MdiShortcutConfiguration.none] to disable all shortcuts.
///
/// Bindings can be customized individually via [copyWith]:
/// ```dart
/// MdiShortcutConfiguration.defaults.copyWith(
///   // Change move keys to Alt + Arrows:
///   moveLeft: [const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)],
///   moveRight: [const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)],
///   moveUp: [const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true)],
///   moveDown: [const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true)],
///   // Disable closing window shortcut:
///   closeWindow: const [],
///   // Custom move distance in pixels:
///   moveStepX: 50.0,
///   moveStepY: 50.0,
/// );
/// ```
@immutable
class MdiShortcutConfiguration {
  /// Shortcuts that close the active front window.
  final List<ShortcutActivator> closeWindow;

  /// Shortcuts that move focus to the next window.
  final List<ShortcutActivator> focusNext;

  /// Shortcuts that move focus to the previous window.
  final List<ShortcutActivator> focusPrevious;

  /// Shortcuts that move the active front window to the left.
  final List<ShortcutActivator> moveLeft;

  /// Shortcuts that move the active front window to the right.
  final List<ShortcutActivator> moveRight;

  /// Shortcuts that move the active front window up.
  final List<ShortcutActivator> moveUp;

  /// Shortcuts that move the active front window down.
  final List<ShortcutActivator> moveDown;

  /// Shortcuts that toggle maximize / restore on the active front window.
  final List<ShortcutActivator> toggleMaximize;

  /// Custom horizontal step distance for window movement shortcuts.
  /// When `null`, defaults to each window's [minWidth].
  final double? moveStepX;

  /// Custom vertical step distance for window movement shortcuts.
  /// When `null`, defaults to each window's [minHeight].
  final double? moveStepY;

  /// Whether keyboard shortcuts are active. When `false`, all shortcuts are ignored.
  final bool enabled;

  const MdiShortcutConfiguration({
    this.closeWindow = const [],
    this.focusNext = const [],
    this.focusPrevious = const [],
    this.moveLeft = const [],
    this.moveRight = const [],
    this.moveUp = const [],
    this.moveDown = const [],
    this.toggleMaximize = const [],
    this.moveStepX,
    this.moveStepY,
    this.enabled = true,
  });

  /// Preset for Desktop platforms (Windows, macOS, Linux).
  static const MdiShortcutConfiguration desktop = MdiShortcutConfiguration(
    closeWindow: [
      SingleActivator(LogicalKeyboardKey.keyW, control: true),
      SingleActivator(LogicalKeyboardKey.f4, control: true),
    ],
    focusNext: [
      SingleActivator(LogicalKeyboardKey.tab, control: true),
      SingleActivator(LogicalKeyboardKey.arrowRight, control: true, alt: true),
      SingleActivator(LogicalKeyboardKey.arrowUp, control: true, alt: true),
    ],
    focusPrevious: [
      SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true),
      SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, alt: true),
      SingleActivator(LogicalKeyboardKey.arrowDown, control: true, alt: true),
    ],
    moveLeft: [
      SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, alt: true, shift: true),
    ],
    moveRight: [
      SingleActivator(LogicalKeyboardKey.arrowRight, control: true, alt: true, shift: true),
    ],
    moveUp: [
      SingleActivator(LogicalKeyboardKey.arrowUp, control: true, alt: true, shift: true),
    ],
    moveDown: [
      SingleActivator(LogicalKeyboardKey.arrowDown, control: true, alt: true, shift: true),
    ],
    toggleMaximize: [],
    enabled: true,
  );

  /// Preset for Web platforms.
  static const MdiShortcutConfiguration web = MdiShortcutConfiguration(
    closeWindow: [
      SingleActivator(LogicalKeyboardKey.keyW, alt: true),
    ],
    focusNext: [
      SingleActivator(LogicalKeyboardKey.period, control: true),
      SingleActivator(LogicalKeyboardKey.arrowRight, control: true, alt: true),
      SingleActivator(LogicalKeyboardKey.arrowUp, control: true, alt: true),
    ],
    focusPrevious: [
      SingleActivator(LogicalKeyboardKey.comma, control: true),
      SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, alt: true),
      SingleActivator(LogicalKeyboardKey.arrowDown, control: true, alt: true),
    ],
    moveLeft: [
      SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, alt: true, shift: true),
    ],
    moveRight: [
      SingleActivator(LogicalKeyboardKey.arrowRight, control: true, alt: true, shift: true),
    ],
    moveUp: [
      SingleActivator(LogicalKeyboardKey.arrowUp, control: true, alt: true, shift: true),
    ],
    moveDown: [
      SingleActivator(LogicalKeyboardKey.arrowDown, control: true, alt: true, shift: true),
    ],
    toggleMaximize: [],
    enabled: true,
  );

  /// Platform-aware default configuration.
  static MdiShortcutConfiguration get defaults => kIsWeb ? web : desktop;

  /// Configuration with all keyboard shortcuts disabled.
  static const MdiShortcutConfiguration none = MdiShortcutConfiguration(
    enabled: false,
  );

  /// Creates a copy of this configuration with the given fields replaced.
  MdiShortcutConfiguration copyWith({
    List<ShortcutActivator>? closeWindow,
    List<ShortcutActivator>? focusNext,
    List<ShortcutActivator>? focusPrevious,
    List<ShortcutActivator>? moveLeft,
    List<ShortcutActivator>? moveRight,
    List<ShortcutActivator>? moveUp,
    List<ShortcutActivator>? moveDown,
    List<ShortcutActivator>? toggleMaximize,
    Object? moveStepX = _kUndefinedShortcut,
    Object? moveStepY = _kUndefinedShortcut,
    bool? enabled,
  }) {
    return MdiShortcutConfiguration(
      closeWindow: closeWindow ?? this.closeWindow,
      focusNext: focusNext ?? this.focusNext,
      focusPrevious: focusPrevious ?? this.focusPrevious,
      moveLeft: moveLeft ?? this.moveLeft,
      moveRight: moveRight ?? this.moveRight,
      moveUp: moveUp ?? this.moveUp,
      moveDown: moveDown ?? this.moveDown,
      toggleMaximize: toggleMaximize ?? this.toggleMaximize,
      moveStepX: identical(moveStepX, _kUndefinedShortcut)
          ? this.moveStepX
          : moveStepX as double?,
      moveStepY: identical(moveStepY, _kUndefinedShortcut)
          ? this.moveStepY
          : moveStepY as double?,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MdiShortcutConfiguration) return false;
    return listEquals(closeWindow, other.closeWindow) &&
        listEquals(focusNext, other.focusNext) &&
        listEquals(focusPrevious, other.focusPrevious) &&
        listEquals(moveLeft, other.moveLeft) &&
        listEquals(moveRight, other.moveRight) &&
        listEquals(moveUp, other.moveUp) &&
        listEquals(moveDown, other.moveDown) &&
        listEquals(toggleMaximize, other.toggleMaximize) &&
        moveStepX == other.moveStepX &&
        moveStepY == other.moveStepY &&
        enabled == other.enabled;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(closeWindow),
        Object.hashAll(focusNext),
        Object.hashAll(focusPrevious),
        Object.hashAll(moveLeft),
        Object.hashAll(moveRight),
        Object.hashAll(moveUp),
        Object.hashAll(moveDown),
        Object.hashAll(toggleMaximize),
        moveStepX,
        moveStepY,
        enabled,
      );
}
