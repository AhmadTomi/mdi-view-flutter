import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_view/mdi_view.dart';

void main() {
  group('MdiController Unit Tests', () {
    late MdiController controller;

    setUp(() {
      controller = MdiController();
      controller.init();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state should be empty', () {
      expect(controller.windows.isEmpty, true);
    });

    test('Add window increases count and sets active window', () {
      final param = ParameterWindow(title: 'Test Window', id: '1');
      controller.addWindow(parameter: param, child: (_) => Container());

      expect(controller.windows.length, 1);
      expect(controller.isWindowExist(param.tag), true);
      expect(controller.frontWindow?.tag, param.tag);
    });

    test('Remove window decreases count', () async {
      final param = ParameterWindow(title: 'Test Window', id: '1');
      controller.addWindow(parameter: param, child: (_) => Container());

      expect(controller.windows.length, 1);

      await controller.removeWindow(param.tag);
      expect(controller.windows.isEmpty, true);
      expect(controller.isWindowExist(param.tag), false);
    });

    test('Adding duplicate tag throws exception', () {
      final param = ParameterWindow(title: 'Test Window', id: '1');
      controller.addWindow(parameter: param, child: (_) => Container());

      expect(
        () => controller.addWindow(parameter: param, child: (_) => Container()),
        throwsStateError,
      );
    });

    test('Remove all windows clears list', () {
      controller.addWindow(
        parameter: ParameterWindow(title: 'W1', id: '1'),
        child: (_) => Container(),
      );
      controller.addWindow(
        parameter: ParameterWindow(title: 'W2', id: '2'),
        child: (_) => Container(),
      );

      expect(controller.windows.length, 2);

      controller.removeAllWindows();
      expect(controller.windows.isEmpty, true);
    });
  });

  group('ParameterWindow Unit Tests', () {
    test('Tag generation is correct', () {
      final param = ParameterWindow(title: 'MyTitle', id: '123');
      expect(param.tag, 'MyTitle.123');
    });

    test('CopyWith works correctly', () {
      final param = ParameterWindow(title: 'A', id: '1', currentWidth: 100);
      final copy = param.copyWith(title: 'B', currentWidth: 200);

      expect(copy.title, 'B');
      expect(copy.currentWidth, 200);
      expect(copy.id, '1'); // Should retain original
    });

  });

  group('MdiStyleConfiguration Unit Tests', () {
    test('showDefaultHeader and draggableBody work with defaults and copyWith', () {
      final style = MdiStyleConfiguration();
      expect(style.showDefaultHeader, true);
      expect(style.draggableBody, true);

      final custom = MdiStyleConfiguration(showDefaultHeader: false, draggableBody: false);
      expect(custom.showDefaultHeader, false);
      expect(custom.draggableBody, false);

      final copy = custom.copyWith(showDefaultHeader: true);
      expect(copy.showDefaultHeader, true);
      expect(copy.draggableBody, false);
    });
  });

  group('MdiManager Widget Tests', () {
    testWidgets('MdiManager renders and shows windows', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();

      // Need a sufficiently large surface
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MdiManager(controller: controller)),
        ),
      );

      // Verify initial empty state (tab bar might be visible though)
      expect(find.byType(MdiManager), findsOneWidget);

      // Add a window
      final windowTitle = "Widget Test Window";
      controller.addWindow(
        parameter: ParameterWindow(title: windowTitle, id: '1'),
        child: (_) => Text('Window Content'),
      );

      await tester.pumpAndSettle();

      // Verify window is in the tree
      expect(find.text(windowTitle), findsNWidgets(2)); // One in tab bar, one in window title bar
      expect(find.text('Window Content'), findsOneWidget); // Content

      controller.dispose();
    });

    testWidgets('MdiManager allows showing dialogs from window content', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      controller.addWindow(
        parameter: const ParameterWindow(title: 'Dialog Test', id: '1'),
        child: (c) => Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('Dialog Title'),
                    content: Text('Dialog Content'),
                  ),
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is in the tree
      expect(find.text('Dialog Title'), findsOneWidget);
      expect(find.text('Dialog Content'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('MdiManager allows showing dialogs nested inside the window context', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      controller.addWindow(
        parameter: const ParameterWindow(title: 'Dialog Test', id: '1'),
        child: (c) => Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  useRootNavigator: false, // Target local navigator!
                  builder: (context) => const AlertDialog(
                    title: Text('Nested Title'),
                    content: Text('Nested Content'),
                  ),
                );
              },
              child: const Text('Show Nested Dialog'),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.text('Show Nested Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is a descendant of ResizableWindow (restricted bounds)
      final dialogFinder = find.text('Nested Title');
      final windowFinder = find.byType(ResizableWindow);
      expect(find.descendant(of: windowFinder, matching: dialogFinder), findsOneWidget);

      controller.dispose();
    });

    testWidgets('MdiManager absorbs pointers and blocks button interaction on unfocused windows', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      int clickCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20),
        child: (c) => ElevatedButton(
          onPressed: () => clickCount++,
          child: const Text('Button 1'),
        ),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W2', id: '2', x: 250, y: 20),
        child: (c) => Container(),
      );

      await tester.pumpAndSettle();

      // Focus should be on W2 (since it was added last)
      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);

      // Tap Button 1 inside unfocused W1
      await tester.tap(find.text('Button 1'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify W1 is now focused, but clickCount is still 0 (blocked!)
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(clickCount, 0);

      // Tap Button 1 again (now that it is focused)
      await tester.tap(find.text('Button 1'));
      await tester.pumpAndSettle();

      // Verify clickCount is now 1 (interaction allowed!)
      expect(clickCount, 1);

      controller.dispose();
    });

    testWidgets('MdiManager absorbs pointers and blocks nested dialog interaction on unfocused windows', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      int cancelClickCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20),
        child: (c) => Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Nested Dialog'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          cancelClickCount++;
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel Button'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Open the dialog inside W1
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Nested Dialog'), findsOneWidget);

      // Add a second window W2 to unfocus W1 (and its dialog)
      final w2 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W2', id: '2', x: 250, y: 20),
        child: (c) => Container(),
      );

      await tester.pumpAndSettle();

      // Focus should be on W2
      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);

      // Tap Cancel Button in unfocused W1's dialog
      await tester.tap(find.text('Cancel Button'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify W1 is now focused, dialog is still open, and cancelClickCount is 0 (blocked!)
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(find.text('Nested Dialog'), findsOneWidget);
      expect(cancelClickCount, 0);

      // Tap Cancel Button again (now that it is focused)
      await tester.tap(find.text('Cancel Button'));
      await tester.pumpAndSettle();

      // Verify dialog is closed and cancelClickCount is 1
      expect(find.text('Nested Dialog'), findsNothing);
      expect(cancelClickCount, 1);

      controller.dispose();
    });

    testWidgets('MdiManager allows dragging an unfocused window seamlessly in a single gesture', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20, currentWidth: 200, currentHeight: 200),
        child: (c) => Container(color: Colors.red),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W2', id: '2', x: 250, y: 20, currentWidth: 200, currentHeight: 200),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      // W2 should have focus
      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);

      // Perform a seamless drag gesture on unfocused window W1
      // Start in the center of W1
      final w1Center = tester.getCenter(find.byWidget(w1.widget));
      await tester.dragFrom(w1Center, const Offset(50, 50), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      // Verify W1 has gained focus and successfully moved
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(w1.x, 70); // 20 + 50
      expect(w1.y, 70); // 20 + 50

      controller.dispose();
    });

    testWidgets('MdiManager allows double-tapping window header to toggle maximize', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 20,
          y: 20,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.red),
      );

      await tester.pumpAndSettle();

      final headerFinder = find.descendant(
        of: find.byType(ResizableWindow),
        matching: find.text('W1'),
      );
      expect(headerFinder, findsOneWidget);

      await tester.tap(headerFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      expect(w1.isMaximized, true);
      expect(w1.x, 0.0);
      expect(w1.y, 0.0);

      // Verify that a single click on a maximized window's header does NOT unmaximize it
      await tester.tap(headerFinder);
      await tester.pump(const Duration(milliseconds: 350)); // Wait past double-tap timeout
      await tester.pumpAndSettle();

      expect(w1.isMaximized, true);
      expect(w1.x, 0.0);
      expect(w1.y, 0.0);

      // Verify double-tapping again successfully restores/unmaximizes it
      await tester.tap(headerFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      expect(w1.isMaximized, false);
      expect(w1.x, 20.0);
      expect(w1.y, 20.0);

      controller.dispose();
    });

    testWidgets('MdiManager maximizes the next focused window when the active maximized window is closed', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 20,
          y: 20,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.red),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 40,
          y: 40,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      final header2Finder = find.descendant(
        of: find.byType(ResizableWindow),
        matching: find.text('W2'),
      );
      expect(header2Finder, findsOneWidget);

      await tester.tap(header2Finder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(header2Finder);
      await tester.pumpAndSettle();

      expect(w2.isMaximized, true);
      expect(w1.isMaximized, false);

      await controller.removeWindow(w2.tag, requestFocusToPrevious: true);
      await tester.pumpAndSettle();

      expect(controller.frontWindow, w1);
      expect(w1.isMaximized, true);
      expect(w1.x, 0.0);
      expect(w1.y, 0.0);

      controller.dispose();
    });

    testWidgets('IgnoreWindowDrag prevents window dragging when dragging inside it', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(
              controller: controller,
              style: MdiStyleConfiguration(
                draggableBody: true,
                showDefaultHeader: true,
              ),
            ),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            const IgnoreWindowDrag(
              child: SizedBox(
                key: Key('ignore-area'),
                height: 100,
                width: 300,
                child: Text('Ignore Drag Area'),
              ),
            ),
            Container(
              key: const Key('drag-area'),
              height: 100,
              width: 300,
              color: Colors.red,
              child: const Text('Drag Area'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Double-check initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from 'ignore-area'
      final TestGesture ignoreGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('ignore-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await ignoreGesture.moveBy(const Offset(50, 50));
      await ignoreGesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from 'drag-area' (outside IgnoreWindowDrag)
      final TestGesture dragGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('drag-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await dragGesture.moveBy(const Offset(50, 50));
      await dragGesture.up();
      await tester.pumpAndSettle();

      // The window should have moved
      expect(w1.x, 150.0);
      expect(w1.y, 150.0);

      controller.dispose();
    });

    testWidgets('Automatic scrollable drag bypass prevents window dragging over ListView', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(
              controller: controller,
              style: MdiStyleConfiguration(
                draggableBody: true,
                showDefaultHeader: true,
              ),
            ),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                key: const Key('list-area'),
                itemCount: 20,
                itemBuilder: (context, index) => ListTile(
                  title: Text('Item $index'),
                ),
              ),
            ),
            Container(
              key: const Key('drag-area'),
              height: 50,
              width: 300,
              color: Colors.red,
              child: const Text('Non-scrollable Drag Area'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Double-check initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from list area (which is scrollable)
      final TestGesture ignoreGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('list-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await ignoreGesture.moveBy(const Offset(50, 50));
      await ignoreGesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from 'drag-area' (outside scrollable area)
      final TestGesture dragGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('drag-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await dragGesture.moveBy(const Offset(50, 50));
      await dragGesture.up();
      await tester.pumpAndSettle();

      // The window should have moved
      expect(w1.x, 150.0);
      expect(w1.y, 150.0);

      controller.dispose();
    });

    testWidgets('Automatic drag bypass prevents window dragging over TextField', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(
              controller: controller,
              style: MdiStyleConfiguration(
                draggableBody: true,
                showDefaultHeader: true,
              ),
            ),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            const SizedBox(
              height: 100,
              width: 300,
              child: Material(
                child: TextField(
                  key: Key('textfield-area'),
                  decoration: InputDecoration(hintText: 'Enter text here'),
                ),
              ),
            ),
            Container(
              key: const Key('drag-area'),
              height: 50,
              width: 300,
              color: Colors.red,
              child: const Text('Non-scrollable Drag Area'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Double-check initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from TextField area
      final TestGesture ignoreGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('textfield-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await ignoreGesture.moveBy(const Offset(50, 50));
      await ignoreGesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from 'drag-area' (outside TextField)
      final TestGesture dragGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('drag-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await dragGesture.moveBy(const Offset(50, 50));
      await dragGesture.up();
      await tester.pumpAndSettle();

      // The window should have moved
      expect(w1.x, 150.0);
      expect(w1.y, 150.0);

      controller.dispose();
    });

    testWidgets('Scroll events inside the window do not propagate to the parent MDI canvas', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);
      // Make canvas larger than screen so vertical scrollbar is active and scrollable
      controller.mdiSize = const Size(800, 1200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(
              controller: controller,
            ),
          ),
        ),
      );

      controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => ListView.builder(
          key: const Key('list-view-key'),
          itemCount: 50,
          itemBuilder: (context, index) => ListTile(
            title: Text('Item $index'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure MDI vertical scroll offset is initially 0
      expect(controller.verticalController.position.pixels, 0.0);

      // Simulate a pointer scroll (mouse wheel scroll) inside the window's ListView
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(find.byKey(const Key('list-view-key'))));
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 50.0)),
      );
      await tester.pumpAndSettle();

      // The parent MDI canvas scroll position should NOT have changed (should remain 0.0)
      expect(controller.verticalController.position.pixels, 0.0);

      controller.dispose();
    });
  });

  group('Enterprise Features Unit Tests', () {
    test('Layout export and import preserves state', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 150,
          currentWidth: 382,
          currentHeight: 474,
          argument: {'test': 'val1'},
        ),
        child: (_) => Container(),
      );

      controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 200,
          y: 250,
          currentWidth: 400,
          currentHeight: 500,
          argument: {'test': 'val2'},
        ),
        child: (_) => Container(),
      );

      expect(controller.windows.length, 2);
      final layout = controller.exportLayout();

      final restoredController = MdiController();
      restoredController.init();
      restoredController.screenSize = const Size(800, 600);

      restoredController.importLayout(layout, childBuilder: (p) => Container());

      expect(restoredController.windows.length, 2);
      expect(restoredController.windows[0].tag, 'W1.1');
      expect(restoredController.windows[0].x, 100);
      expect(restoredController.windows[0].y, 150);
      expect(restoredController.windows[0].currentWidth, 382);
      expect(restoredController.windows[0].currentHeight, 474);
      expect(restoredController.windows[0].argument['test'], 'val1');

      expect(restoredController.windows[1].tag, 'W2.2');
      expect(restoredController.windows[1].x, 200);
      expect(restoredController.windows[1].y, 250);
      expect(restoredController.windows[1].currentWidth, 400);
      expect(restoredController.windows[1].currentHeight, 500);
      expect(restoredController.windows[1].argument['test'], 'val2');

      controller.dispose();
      restoredController.dispose();
    });

    test('Snapping to other windows aligns edges correctly', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 800);

      controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (_) => Container(),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 308, // Close to w1.right (100 + 200 = 300)
          y: 108, // Close to w1.top (100)
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (_) => Container(),
      );

      w2.x = 308;
      w2.y = 108;
      w2.onHorizontalLeftDragEnd(DragEndDetails()); // should snap left edge to w1's right (300)
      expect(w2.x, 300.0);
      expect(w2.currentWidth, 208.0); // snapped left from 308 to 300, widening it

      w2.x = 308;
      w2.y = 108;
      w2.onVerticalDragTopEnd(DragEndDetails());
      expect(w2.y, 100.0); // snapped top to w1's top (100)

      controller.dispose();
    });

    test('Layout reconciliation preserves existing window controller instances', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 150,
        ),
        child: (_) => Container(),
      );

      final layoutBefore = controller.exportLayout();
      
      // Update coordinates in layout map manually
      layoutBefore[0]['x'] = 120.0;
      layoutBefore[0]['y'] = 170.0;

      // Import layout and ensure the controller reference is the exact same instance (identical)
      controller.importLayout(layoutBefore, childBuilder: (p) => Container());

      expect(controller.windows.length, 1);
      final reconciledW1 = controller.getWindow('W1.1');
      expect(reconciledW1, isNotNull);
      expect(identical(reconciledW1, w1), true); // Verify instance identity is preserved!
      expect(reconciledW1!.x, 120.0);
      expect(reconciledW1.y, 170.0);

      controller.dispose();
    });
  });
}
