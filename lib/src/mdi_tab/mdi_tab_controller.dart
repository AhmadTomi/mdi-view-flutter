part of 'mdi_tab.dart';

/// Manages the tab strip state: ordered list of window controllers,
/// scroll position, and scroll-arrow visibility.
///
/// This controller does **not** own the [ResizeableWindowController] instances;
/// it only holds references.  Ownership stays with [MdiController].
class MdiTabController extends ChangeNotifier {
  // ── Scroll ────────────────────────────────────────────────────────────────

  final ScrollController tabScrollController = ScrollController();

  static const double _kScrollStep = 80.0;

  // ── Tab order map ─────────────────────────────────────────────────────────

  /// Ordered map — insertion order == tab order.
  final Map<String, ResizeableWindowController> _tabs = {};

  List<ResizeableWindowController> get tabControllers =>
      List.unmodifiable(_tabs.values);

  int get length => _tabs.length;

  // ── Navigation button visibility ──────────────────────────────────────────

  bool _showLeft = false;
  bool _showRight = false;
  bool _showNav = false;

  bool get showLeftButton => _showLeft;
  bool get showRightButton => _showRight;
  bool get showTabNavButton => _showNav;

  // ── Tab drag & reorder state ──────────────────────────────────────────────

  bool _isDraggingTab = false;
  int? _draggedTabIndex;
  int? _dropTargetIndex;
  String? _draggedTabTag;
  double _dragPointerLocalX = 0.0;
  double _dragGrabOffsetX = 0.0;
  double _draggedTabWidth = 0.0;
  List<double> _cachedTabWidths = [];
  Timer? _autoScrollTimer;

  bool get isDraggingTab => _isDraggingTab;
  int? get draggedTabIndex => _draggedTabIndex;
  int? get dropTargetIndex => _dropTargetIndex;
  String? get draggedTabTag => _draggedTabTag;
  double get dragPointerLocalX => _dragPointerLocalX;
  double get dragGrabOffsetX => _dragGrabOffsetX;
  double get draggedTabWidth => _draggedTabWidth;
  List<double> get cachedTabWidths => _cachedTabWidths;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void init() {
    tabScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    tabScrollController.removeListener(_onScroll);
    tabScrollController.dispose();
    _tabs.clear();
    super.dispose();
  }

  // ── Tab mutations ─────────────────────────────────────────────────────────

  /// Registers a tab.  No-op if [tag] already exists.
  void addTab(String tag, ResizeableWindowController controller) {
    if (_tabs.containsKey(tag)) return;
    _tabs[tag] = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabScrollCheck();
    });
    // Notification is the caller's responsibility (MdiController will notify).
  }

  /// Removes a tab.  No-op if [tag] is absent.
  void removeTab(String tag) {
    _tabs.remove(tag);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabScrollCheck();
    });
  }

  /// Moves a tab from [oldIndex] directly to [targetIndex].
  void moveTab(int oldIndex, int targetIndex) {
    final len = _tabs.length;
    if (oldIndex < 0 ||
        oldIndex >= len ||
        targetIndex < 0 ||
        targetIndex >= len ||
        oldIndex == targetIndex) {
      return;
    }

    final list = _tabs.values.toList();
    final item = list.removeAt(oldIndex);
    list.insert(targetIndex, item);

    _tabs
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.tag, c)));

    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabScrollCheck();
    });
  }

  /// Reorders tabs from [oldIndex] to [newIndex] (standard Flutter semantics).
  void reorderTabs(int oldIndex, int newIndex) {
    final len = _tabs.length;
    if (oldIndex < 0 ||
        oldIndex >= len ||
        newIndex < 0 ||
        newIndex > len ||
        oldIndex == newIndex) {
      return;
    }

    final effectiveNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    moveTab(oldIndex, effectiveNew);
  }

  void setTabs(List<ResizeableWindowController> list) {
    _tabs
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.tag, c)));
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabScrollCheck();
    });
  }

  // ── Tab Drag Lifecycle ────────────────────────────────────────────────────

  void startTabDrag({
    required int index,
    required double pointerLocalX,
    required double grabOffsetX,
    required double tabWidth,
    required List<double> tabWidths,
  }) {
    if (index < 0 || index >= _tabs.length) return;
    _isDraggingTab = true;
    _draggedTabIndex = index;
    _dropTargetIndex = index;
    _draggedTabTag = _tabs.values.elementAt(index).tag;
    _dragPointerLocalX = pointerLocalX;
    _dragGrabOffsetX = grabOffsetX;
    _draggedTabWidth = tabWidth;
    _cachedTabWidths = List.unmodifiable(tabWidths);
    notifyListeners();
  }

  void updateTabDrag({
    required double pointerLocalX,
    required double scrollOffset,
  }) {
    if (!_isDraggingTab || _draggedTabIndex == null) return;
    _dragPointerLocalX = pointerLocalX;

    // Calculate center of dragged tab in scrollable content coordinates
    final tabLeft = pointerLocalX - _dragGrabOffsetX + scrollOffset;
    final tabCenter = tabLeft + (_draggedTabWidth / 2.0);
    final target = calculateDropTargetIndex(tabCenter);
    if (target != _dropTargetIndex) {
      _dropTargetIndex = target;
    }
    notifyListeners();
  }

  int calculateDropTargetIndex(double dragCenterX) {
    if (_cachedTabWidths.isEmpty) return _draggedTabIndex ?? 0;

    double accumulatedWidth = 0.0;
    for (int i = 0; i < _cachedTabWidths.length; i++) {
      final width = _cachedTabWidths[i];
      final midpoint = accumulatedWidth + (width / 2.0);
      if (dragCenterX < midpoint) {
        return i;
      }
      accumulatedWidth += width;
    }
    return _cachedTabWidths.length - 1;
  }

  void checkEdgeAutoScroll(double localX, double viewportWidth) {
    if (!_isDraggingTab) {
      _stopAutoScroll();
      return;
    }
    const edgeMargin = 40.0;
    const scrollStep = 6.0;

    if (localX < edgeMargin &&
        tabScrollController.hasClients &&
        tabScrollController.offset > tabScrollController.position.minScrollExtent) {
      final speedFactor =
          ((edgeMargin - localX) / edgeMargin).clamp(0.2, 1.0);
      _startAutoScroll(-scrollStep * speedFactor);
    } else if (localX > viewportWidth - edgeMargin &&
        tabScrollController.hasClients &&
        tabScrollController.offset < tabScrollController.position.maxScrollExtent) {
      final speedFactor =
          ((localX - (viewportWidth - edgeMargin)) / edgeMargin).clamp(0.2, 1.0);
      _startAutoScroll(scrollStep * speedFactor);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double delta) {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!tabScrollController.hasClients || !_isDraggingTab) {
        _stopAutoScroll();
        return;
      }
      final pos = tabScrollController.position;
      final newOffset = (tabScrollController.offset + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      tabScrollController.jumpTo(newOffset);
      updateTabDrag(
        pointerLocalX: _dragPointerLocalX,
        scrollOffset: newOffset,
      );
      if (newOffset <= pos.minScrollExtent || newOffset >= pos.maxScrollExtent) {
        _stopAutoScroll();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void endTabDrag() {
    if (!_isDraggingTab) return;
    _stopAutoScroll();
    final fromIndex = _draggedTabIndex;
    final toIndex = _dropTargetIndex;

    _isDraggingTab = false;
    _draggedTabIndex = null;
    _dropTargetIndex = null;
    _draggedTabTag = null;
    _cachedTabWidths = [];

    if (fromIndex != null && toIndex != null && fromIndex != toIndex) {
      moveTab(fromIndex, toIndex);
    } else {
      notifyListeners();
    }
  }

  void cancelTabDrag() {
    if (!_isDraggingTab) return;
    _stopAutoScroll();
    _isDraggingTab = false;
    _draggedTabIndex = null;
    _dropTargetIndex = null;
    _draggedTabTag = null;
    _cachedTabWidths = [];
    notifyListeners();
  }

  // ── Scroll helpers ────────────────────────────────────────────────────────

  void scrollLeft() => _scrollBy(-_kScrollStep);
  void scrollRight() => _scrollBy(_kScrollStep);

  void _scrollBy(double delta) {
    if (!tabScrollController.hasClients) return;
    final pos = tabScrollController.position;
    tabScrollController.animateTo(
      (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Recalculates button visibility; notifies only when the values change.
  void tabScrollCheck() {
    final bool prevLeft = _showLeft;
    final bool prevRight = _showRight;
    final bool prevNav = _showNav;

    if (!tabScrollController.hasClients ||
        tabScrollController.position.maxScrollExtent == 0.0) {
      _showLeft = false;
      _showRight = false;
      _showNav = false;
    } else {
      final pos = tabScrollController.position;
      _showLeft = pos.pixels > pos.minScrollExtent;
      _showRight = pos.pixels < pos.maxScrollExtent;
      _showNav = _showLeft || _showRight;
    }

    if (_showLeft != prevLeft ||
        _showRight != prevRight ||
        _showNav != prevNav) {
      notifyListeners();
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _onScroll() => tabScrollCheck();
}
