part of '../../mdi_view.dart';

class ParameterWindow {
  // Private fields
  final String _id;
  final String _title;
  Map<String, dynamic> _argument;

  // Public fields
  final double minWidth;
  final double minHeight;
  double currentWidth;
  double currentHeight;
  double x;
  double y;

  // Static constants
  static double defaultWidth = 382.0;
  static double defaultHeight = 474.0;
  static double splitWidth = 1.0;
  static double splitHeight = 4.0;

  static double get defaultMinWidth => defaultWidth / splitWidth;
  static double get defaultMinHeight => defaultHeight / splitHeight;

  // Constructor with required parameters and default values
  ParameterWindow({
    String? id,
    required String title,
    Map<String, dynamic> argument = const {},
    double? minHeight,
    double? minWidth,
    double? currentWidth,
    double? currentHeight,
    this.x = -1.0,
    this.y = -1.0,
  }) : _id = id ?? "Primary",
       _title = title,
       _argument = Map.of(argument),
       currentWidth = currentWidth ?? defaultWidth,
       currentHeight = currentHeight ?? defaultHeight,
       minHeight = minHeight ?? defaultMinHeight,
       minWidth = minWidth ?? defaultMinWidth;

  // Getters for private fields
  String get id => _id;
  String get title => _title;
  String get tag => "$_title.$_id";
  bool get isMaximize => (_argument[KeyMapVariable.isMaximize] ?? '0') == '1';
  Map<String, dynamic> get argument => _argument;
  void setArgument(Map<String, dynamic> args) => _argument = args;
  void setMaximize(bool isMaximize) =>
      _argument[KeyMapVariable.isMaximize] = isMaximize ? "1" : "0";

  // Method to get width scale
  static int getWidthScale(double width) {
    int result = (width + 6) ~/ defaultWidth;
    return result < 1 ? 1 : result;
  }

  // Method to get height scale
  static int getHeightScale(double height) {
    int result = (height + 6) ~/ defaultHeight;
    return result < 1 ? 0 : result;
  }

  void updateParameter({
    String? argument,
    double? width,
    double? height,
    double? posX,
    double? posY,
  }) {
    x = posX ?? x;
    y = posY ?? y;
    currentWidth = width ?? currentWidth;
    currentHeight = height ?? currentHeight;
  }

  double get cornerX => x + currentWidth;
  double get cornerY => y + currentHeight;

  void debugLog() {
    print("id:$_id");
    print("title:$_title");
    print("Position: $x,$y");
    print("CuprintrrentSize:$currentWidth,$currentHeight");
  }

  // CopyWith method
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
      id: id ?? _id,
      title: title ?? _title,
      argument: argument ?? _argument,
      minHeight: minHeight ?? this.minHeight,
      minWidth: minWidth ?? this.minWidth,
      currentWidth: currentWidth ?? this.currentWidth,
      currentHeight: currentHeight ?? this.currentHeight,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  ParameterWindow get clone {
    return ParameterWindow(
      id: id,
      title: title,
      argument: argument,
      minHeight: minHeight,
      minWidth: minWidth,
      currentWidth: currentWidth,
      currentHeight: currentHeight,
      x: x,
      y: y,
    );
  }

  bool isSame(ParameterWindow data, {bool printDebug = false}) {
    if (_title != data.title) {
      // if(printDebug)appLog.debug("TITLE : $_title != ${data.title}");
      return false;
    }

    if (_argument.toString() != data.argument.toString()) {
      if (printDebug) print("ARGS : $_argument != ${data.argument}");
      return false;
    }

    if (currentWidth != data.currentWidth) {
      if (printDebug) print("WIDTH : $currentWidth != ${data.currentWidth}");
      return false;
    }

    if (currentHeight != data.currentHeight) {
      if (printDebug) print("HEIGHT : $currentHeight != ${data.currentHeight}");
      return false;
    }

    if (x != data.x) {
      if (printDebug) print("X : $x != ${data.x}");
      return false;
    }

    if (y != data.y) {
      if (printDebug) print("Y : $y != ${data.y}");
      return false;
    }

    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': _id,
      'title': _title,
      'argument': _argument,
      'minWidth': minWidth,
      'minHeight': minHeight,
      'currentWidth': currentWidth,
      'currentHeight': currentHeight,
      'x': x,
      'y': y,
    };
  }

  // Deserialize the object from JSON
  factory ParameterWindow.fromJson(Map<String, dynamic> json) {
    return ParameterWindow(
      id: json['id'] as String?,
      title: json['title'] as String,
      argument: json['argument'] as Map<String, dynamic>,
      minWidth: json['minWidth'] as double?,
      minHeight: json['minHeight'] as double?,
      currentWidth: json['currentWidth'] as double? ?? defaultWidth,
      currentHeight: json['currentHeight'] as double? ?? defaultHeight,
      x: json['x'] as double? ?? -1.0,
      y: json['y'] as double? ?? -1.0,
    );
  }
}

abstract class KeyMapVariable {
  static String isMaximize = "isMaximize";
}

abstract class ParameterWindowHelper {}
