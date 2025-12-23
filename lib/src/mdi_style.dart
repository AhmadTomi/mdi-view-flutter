part of '../../mdi_view.dart';

class MdiStyleProvider extends InheritedWidget {
  final MdiStyleConfiguration style;

  const MdiStyleProvider({
    super.key,
    required this.style,
    required super.child,
  });

  static MdiStyleConfiguration of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MdiStyleProvider>()
            ?.style ??
        MdiStyleConfiguration();
  }

  @override
  bool updateShouldNotify(MdiStyleProvider oldWidget) {
    return oldWidget.style != style;
  }
}

class MdiStyleConfiguration {
  final Color focusedBorderColor;
  final Color unfocusedBorderColor;
  final Color unfocusBlockerColor;
  final Color maximizedBorderColor;
  final double borderWidth;
  final double gap;
  final double borderRadius;
  final Color mdiBackgroundColor;
  final Color windowBackgroundColor;
  final Color tabBackgroundColor;
  final Color tabSplashColor;
  final Color focusedTabTextColor;
  final Color unfocusedTabTextColor;
  final Color unfocusedTabMenuColor;
  final Color focusedTabMenuColor;
  final double tabMenuMinWidth;

  MdiStyleConfiguration({
    this.gap = 1,
    this.focusedBorderColor = Colors.blue,
    this.unfocusedBorderColor = Colors.blueGrey,
    this.maximizedBorderColor = Colors.blueGrey,
    this.windowBackgroundColor = Colors.white,
    this.mdiBackgroundColor = Colors.grey,
    this.tabMenuMinWidth = 40,
    Color? focusedTabTextColor,
    Color? unfocusedTabTextColor,
    Color? focusedTabMenuColor,
    Color? unfocusedTabMenuColor,
    Color? tabBackgroundColor,
    Color? tabSplashColor,

    Color? unfocusBlockerColor,

    this.borderWidth = 1.5,
    this.borderRadius = 4,
  }) : unfocusBlockerColor =
           unfocusBlockerColor ?? Colors.grey.withValues(alpha: 0.2),
       focusedTabTextColor = focusedTabTextColor ?? Colors.white,
       unfocusedTabTextColor = unfocusedTabTextColor ?? Colors.white70,
       focusedTabMenuColor = focusedTabMenuColor ?? Colors.blue,
       unfocusedTabMenuColor = unfocusedTabMenuColor ?? Colors.blue.shade700,
       tabBackgroundColor = tabBackgroundColor ?? Colors.blue.shade700,
       tabSplashColor = tabSplashColor ?? Colors.blue.shade400;
}
