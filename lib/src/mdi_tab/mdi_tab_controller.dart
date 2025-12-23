part of 'mdi_tab.dart';

class MdiTabController extends ChangeNotifier {
  final ScrollController tabScrollController = ScrollController();
  final Map<String, ResizeableWindowController> _tabControllers = {};
  List<ResizeableWindowController> get tabControllers =>
      _tabControllers.values.toList();
  int get length => _tabControllers.length;

  bool _showLeftButton = false;
  bool _showRightButton = false;
  bool _showNavTabButton = false;
  final double _scrollAmount = 80.0;
  final double menuWidth = 60.0;

  bool get showLeftButton => _showLeftButton;
  bool get showRightButton => _showRightButton;
  bool get showTabNavButton => _showNavTabButton;

  void init() {
    tabScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    tabScrollController.removeListener(_scrollListener);
    super.dispose();
  }

  // Method to add a tab
  void addTab(String tag, ResizeableWindowController controller) {
    if (!_tabControllers.containsKey(tag)) {
      _tabControllers[tag] = controller;
      // We don't notify listeners here because MdiController
      // will notify its own listeners (MdiManager)
    }
  }

  // Method to remove a tab
  void removeTab(String tag) {
    if (_tabControllers.containsKey(tag)) {
      _tabControllers.remove(tag);
      // We don't notify listeners here, MdiController will
    }
  }

  // Method to reorder tabs
  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _tabControllers.length ||
        newIndex < 0 ||
        newIndex > _tabControllers.length || // Allow newIndex == length
        oldIndex == newIndex) {
      return;
    }
    final List<ResizeableWindowController> tempControllers = _tabControllers
        .values
        .toList();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final ResizeableWindowController item = tempControllers.removeAt(oldIndex);
    tempControllers.insert(newIndex, item);

    _tabControllers.clear();
    for (final controller in tempControllers) {
      _tabControllers[controller.tag] = controller;
    }
    // Notify listeners here because this change *only* affects the tab widget
    notifyListeners();
  }

  // CODE TAB WIDGET
  void _scrollListener() {
    tabScrollCheck();
  }

  void tabScrollCheck() {
    // Store old values to check for a change
    final bool oldShowLeft = _showLeftButton;
    final bool oldShowRight = _showRightButton;
    final bool oldShowNav = _showNavTabButton;

    if (!tabScrollController.hasClients ||
        tabScrollController.position.maxScrollExtent == 0.0) {
      // No scroll, so hide all buttons
      _showLeftButton = false;
      _showRightButton = false;
      _showNavTabButton = false;
    } else {
      // Has scroll, check positions
      double maxScroll = tabScrollController.position.maxScrollExtent;
      double currentScroll = tabScrollController.position.pixels;
      double minScroll = tabScrollController.position.minScrollExtent;

      _showLeftButton = currentScroll > minScroll;
      _showRightButton = currentScroll < maxScroll;
      _showNavTabButton = (_showRightButton || _showLeftButton);
    }

    if (oldShowLeft != _showLeftButton ||
        oldShowRight != _showRightButton ||
        oldShowNav != _showNavTabButton) {
      notifyListeners();
    }
  }

  void scrollLeft() {
    double newOffset = (tabScrollController.offset - _scrollAmount).clamp(
      tabScrollController.position.minScrollExtent,
      tabScrollController.position.maxScrollExtent,
    );
    tabScrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void scrollRight() {
    double newOffset = (tabScrollController.offset + _scrollAmount).clamp(
      tabScrollController.position.minScrollExtent,
      tabScrollController.position.maxScrollExtent,
    );
    tabScrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
