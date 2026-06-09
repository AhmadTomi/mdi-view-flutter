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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void init() {
    tabScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    tabScrollController.removeListener(_onScroll);
    tabScrollController.dispose();
    super.dispose();
  }

  // ── Tab mutations ─────────────────────────────────────────────────────────

  /// Registers a tab.  No-op if [tag] already exists.
  void addTab(String tag, ResizeableWindowController controller) {
    if (_tabs.containsKey(tag)) return;
    _tabs[tag] = controller;
    // Notification is the caller's responsibility (MdiController will notify).
  }

  /// Removes a tab.  No-op if [tag] is absent.
  void removeTab(String tag) => _tabs.remove(tag);

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

    final list = _tabs.values.toList();
    final effectiveNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    list.insert(effectiveNew, list.removeAt(oldIndex));

    _tabs
      ..clear()
      ..addEntries(list.map((c) => MapEntry(c.tag, c)));

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
