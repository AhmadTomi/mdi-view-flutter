import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

    testWidgets('Automatic drag bypass prevents window dragging over Slider', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      double sliderValue = 20.0;

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
          title: 'Slider Window',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              SizedBox(
                height: 100,
                width: 300,
                child: Material(
                  child: Slider(
                    key: const Key('slider-key'),
                    value: sliderValue,
                    min: 0,
                    max: 100,
                    onChanged: (val) {
                      setState(() {
                        sliderValue = val;
                      });
                    },
                  ),
                ),
              ),
              Container(
                key: const Key('empty-drag-area'),
                height: 50,
                width: 300,
                color: Colors.blue,
                child: const Text('Draggable background'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-check initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from Slider area
      final TestGesture sliderGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('slider-key'))),
        kind: PointerDeviceKind.mouse,
      );
      await sliderGesture.moveBy(const Offset(50, 0));
      await sliderGesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved, and slider value should have updated
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);
      expect(sliderValue, isNot(20.0));

      // Attempt to drag from 'empty-drag-area' (outside Slider)
      final TestGesture dragGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('empty-drag-area'))),
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

    testWidgets('Automatic drag bypass prevents window dragging over custom horizontal drag handler', (
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
          title: 'Custom Gesture Window',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            GestureDetector(
              key: const Key('custom-drag-gesture'),
              onHorizontalDragUpdate: (details) {},
              child: Container(
                height: 80,
                width: 300,
                color: Colors.green,
                child: const Text('Custom Drag Area'),
              ),
            ),
            Container(
              key: const Key('empty-drag-area'),
              height: 50,
              width: 300,
              color: Colors.blue,
              child: const Text('Draggable background'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from custom drag gesture area
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('custom-drag-gesture'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(40, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Drag from empty drag area
      final TestGesture bgGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('empty-drag-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await bgGesture.moveBy(const Offset(50, 50));
      await bgGesture.up();
      await tester.pumpAndSettle();

      // The window should have moved
      expect(w1.x, 150.0);
      expect(w1.y, 150.0);

      controller.dispose();
    });

    testWidgets('Automatic drag bypass prevents window dragging over RenderPointerListener with onPointerMove', (
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
          title: 'Pointer Listener Window',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            Listener(
              key: const Key('custom-pointer-listener'),
              onPointerMove: (event) {},
              child: Container(
                height: 80,
                width: 300,
                color: Colors.amber,
                child: const Text('Pointer Move Area'),
              ),
            ),
            Container(
              key: const Key('empty-drag-area'),
              height: 50,
              width: 300,
              color: Colors.blue,
              child: const Text('Draggable background'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Initial position
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Attempt to drag from pointer listener area
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('custom-pointer-listener'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(40, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      // The window should NOT have moved
      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      controller.dispose();
    });

    testWidgets('shouldIgnoreDragTarget predicate in MdiStyleConfiguration is respected', (
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
                shouldIgnoreDragTarget: (target) =>
                    target.runtimeType.toString() == 'RenderCustomCardBox',
              ),
            ),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'Custom Predicate Window',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Container(
          key: const Key('empty-drag-area'),
          height: 300,
          width: 300,
          color: Colors.blue,
        ),
      );

      await tester.pumpAndSettle();

      // Drag from empty drag area (not matching predicate)
      final TestGesture bgGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('empty-drag-area'))),
        kind: PointerDeviceKind.mouse,
      );
      await bgGesture.moveBy(const Offset(50, 50));
      await bgGesture.up();
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

      final scrollController = ScrollController();

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
          controller: scrollController,
          itemCount: 50,
          itemBuilder: (context, index) => ListTile(
            title: Text('Item $index'),
          ),
        ),
      );

      // Focus the window to disable the unfocus blocker overlay
      controller.bringToFront('1', focus: true);
      await tester.pumpAndSettle();

      // Ensure MDI vertical scroll offset is initially 0
      expect(controller.verticalController.position.pixels, 0.0);
      expect(scrollController.offset, 0.0);

      // Simulate a pointer scroll (mouse wheel scroll) inside the window's ListView
      final Offset center = tester.getCenter(find.byKey(const Key('list-view-key')));
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);
      
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 50.0)),
      );
      await tester.pumpAndSettle();

      // The parent MDI canvas scroll position should NOT have changed (should remain 0.0)
      expect(controller.verticalController.position.pixels, 0.0);

      // Verify that the ListView itself scrolled
      expect(scrollController.offset, 50.0);

      scrollController.dispose();
      controller.dispose();
    });

    testWidgets('Scroll events over empty space or non-scrollable widgets inside the window scroll the parent MDI canvas', (
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
          title: 'Non-Scrollable Window',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 300,
          currentHeight: 300,
        ),
        child: (_) => Column(
          children: [
            Container(
              key: const Key('card-key'),
              height: 150,
              width: 300,
              color: Colors.blue,
              child: const Text('Non-scrollable card container'),
            ),
            Container(
              key: const Key('empty-space-key'),
              height: 100,
              width: 300,
              color: Colors.grey,
            ),
          ],
        ),
      );

      // Add a window positioned further down and right to expand canvas beyond screen size
      controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 1000,
          y: 800,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (_) => Container(),
      );

      await tester.pumpAndSettle();
      controller.verticalController.jumpTo(0.0);
      controller.horizontalController.jumpTo(0.0);
      await tester.pump();

      // Ensure MDI vertical and horizontal scroll offset is initially 0
      expect(controller.verticalController.position.pixels, 0.0);
      expect(controller.horizontalController.position.pixels, 0.0);

      // Simulate a pointer scroll inside the non-scrollable card container
      final Offset cardCenter = tester.getCenter(find.byKey(const Key('card-key')));
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(cardCenter);

      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 50.0)),
      );
      await tester.pumpAndSettle();

      // The parent MDI canvas scroll position SHOULD have scrolled by 50.0
      expect(controller.verticalController.position.pixels, 50.0);

      // Simulate a pointer scroll over the empty space
      final Offset emptyCenter = tester.getCenter(find.byKey(const Key('empty-space-key')));
      pointer.hover(emptyCenter);

      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 30.0)),
      );
      await tester.pumpAndSettle();

      // The parent MDI canvas scroll position SHOULD now be 80.0
      expect(controller.verticalController.position.pixels, 80.0);

      // Simulate a pointer scroll over the default window header (title bar at x=150, y=115)
      pointer.hover(const Offset(150, 115));
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 20.0)),
      );
      await tester.pumpAndSettle();

      // The parent MDI canvas scroll position SHOULD now be 100.0
      expect(controller.verticalController.position.pixels, 100.0);

      // Test Shift + scroll triggers horizontal scrolling
      controller.verticalController.jumpTo(0.0);
      controller.horizontalController.jumpTo(0.0);
      await tester.pump();
      expect(controller.verticalController.position.pixels, 0.0);
      expect(controller.horizontalController.position.pixels, 0.0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      pointer.hover(cardCenter);
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0.0, 45.0)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      // Horizontal should have scrolled by 45.0, vertical remains 0.0
      expect(controller.horizontalController.position.pixels, 45.0);
      expect(controller.verticalController.position.pixels, 0.0);

      controller.dispose();
    });

    testWidgets('Hovering over a window updates isHoveringAnyWindow and scroll physics', (
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
        child: (_) => Container(),
      );

      await tester.pumpAndSettle();

      // Initially not hovering
      expect(controller.isHoveringAnyWindow, isFalse);

      // Hover over the window (center of the window is at x=250, y=250)
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(const Offset(250, 250)),
      );
      await tester.pumpAndSettle();

      // Should be hovering now
      expect(controller.isHoveringAnyWindow, isTrue);

      // Hover outside the window (e.g. at x=50, y=50)
      await tester.sendEventToBinding(
        pointer.hover(const Offset(50, 50)),
      );
      await tester.pumpAndSettle();

      // Should not be hovering anymore
      expect(controller.isHoveringAnyWindow, isFalse);

      controller.dispose();
    });

    testWidgets('Hovering over an unfocused window makes _UnfocusBlocker disappear and allows immediate child button click', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(800, 600);

      int clickCount = 0;
      bool? onHoverCallbackValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdiManager(controller: controller),
          ),
        ),
      );

      final w1 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20, currentWidth: 200, currentHeight: 200),
        child: (c) => ElevatedButton(
          onPressed: () => clickCount++,
          child: const Text('Hover Button 1'),
        ),
      );

      w1.onHover = (isHovered) {
        onHoverCallbackValue = isHovered;
      };

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(title: 'W2', id: '2', x: 250, y: 20, currentWidth: 200, currentHeight: 200),
        child: (c) => Container(),
      );

      await tester.pumpAndSettle();

      // Initial checks: W2 has focus, W1 is unfocused and not hovered
      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);
      expect(w1.isHovered, false);
      expect(w1.hoverNotifier.value, false);

      // Hover over W1 with a mouse pointer
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      final w1ButtonCenter = tester.getCenter(find.text('Hover Button 1'));
      await tester.sendEventToBinding(pointer.hover(w1ButtonCenter));
      await tester.pumpAndSettle();

      // Verify W1 hover state updated
      expect(w1.isHovered, true);
      expect(w1.hoverNotifier.value, true);
      expect(onHoverCallbackValue, true);

      // Click button while hovering — since _UnfocusBlocker is gone, click must hit button immediately!
      await tester.sendEventToBinding(pointer.down(w1ButtonCenter));
      await tester.sendEventToBinding(pointer.up());
      await tester.pumpAndSettle();

      expect(clickCount, 1);

      // Hover away from W1
      await tester.sendEventToBinding(pointer.hover(const Offset(500, 500)));
      await tester.pumpAndSettle();

      expect(w1.isHovered, false);
      expect(w1.hoverNotifier.value, false);
      expect(onHoverCallbackValue, false);

      controller.dispose();
    });

    testWidgets('Child widget builder reactively updates when hover state changes', (
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
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20, currentWidth: 200, currentHeight: 200),
        child: (ctrl) => Container(
          key: const Key('reactive-container'),
          child: Text(ctrl.isHovered ? 'Child is Hovered' : 'Child is Idle'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Child is Idle'), findsOneWidget);
      expect(find.text('Child is Hovered'), findsNothing);

      // Hover over W1
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      final w1Center = tester.getCenter(find.byKey(const Key('reactive-container')));
      await tester.sendEventToBinding(pointer.hover(w1Center));
      await tester.pumpAndSettle();

      // Child builder should automatically rebuild with 'Child is Hovered'
      expect(find.text('Child is Hovered'), findsOneWidget);
      expect(find.text('Child is Idle'), findsNothing);

      // Hover outside
      await tester.sendEventToBinding(pointer.hover(const Offset(500, 500)));
      await tester.pumpAndSettle();

      expect(find.text('Child is Idle'), findsOneWidget);
      expect(find.text('Child is Hovered'), findsNothing);

      controller.dispose();
    });

    testWidgets('Child widget can use hoverNotifier ValueListenable directly', (
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
        parameter: const ParameterWindow(title: 'W1', id: '1', x: 20, y: 20, currentWidth: 200, currentHeight: 200),
        child: (ctrl) => ValueListenableBuilder<bool>(
          valueListenable: ctrl.hoverNotifier,
          builder: (context, isHovered, _) {
            return Text(
              isHovered ? 'Notifier Hovered' : 'Notifier Idle',
              key: const Key('notifier-text'),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifier Idle'), findsOneWidget);

      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      final w1Center = tester.getCenter(find.byKey(const Key('notifier-text')));
      await tester.sendEventToBinding(pointer.hover(w1Center));
      await tester.pumpAndSettle();

      expect(find.text('Notifier Hovered'), findsOneWidget);

      await tester.sendEventToBinding(pointer.hover(const Offset(500, 500)));
      await tester.pumpAndSettle();

      expect(find.text('Notifier Idle'), findsOneWidget);

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

    test('Horizontal resize snaps to multiples of minWidth within snapRange', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 800);

      final w = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W',
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

      // 1. Within snapRange (diff: 15 < 30) -> snaps to 300
      w.currentWidth = 285;
      w.onHorizontalRightDragEnd(DragEndDetails());
      expect(w.currentWidth, 300.0);

      // 2. Outside snapRange (diff: 50 >= 30) -> does not snap
      w.currentWidth = 250;
      w.onHorizontalRightDragEnd(DragEndDetails());
      expect(w.currentWidth, 250.0);

      // 3. Resize left edge within snapRange preserves right edge
      w.x = 105;
      w.currentWidth = 285; // Right edge is 105 + 285 = 390.
      w.onHorizontalLeftDragEnd(DragEndDetails());
      expect(w.currentWidth, 300.0);
      expect(w.x + w.currentWidth, 390.0); // right edge preserved

      controller.dispose();
    });

    test('Vertical resize snaps to multiples of minHeight within snapRange', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 800);

      final w = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W',
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

      // 1. Within snapRange (diff: 10 < 30) -> snaps to 200
      w.currentHeight = 190;
      w.onVerticalDragBottomEnd(DragEndDetails());
      expect(w.currentHeight, 200.0);

      // 2. Outside snapRange (diff: 50 >= 30) -> does not snap
      w.currentHeight = 150;
      w.onVerticalDragBottomEnd(DragEndDetails());
      expect(w.currentHeight, 150.0);

      // 3. Resize top edge within snapRange preserves bottom edge
      w.y = 100;
      w.currentHeight = 190; // Bottom edge is 100 + 190 = 290.
      w.onVerticalDragTopEnd(DragEndDetails());
      expect(w.currentHeight, 200.0);
      expect(w.y + w.currentHeight, 290.0); // bottom edge preserved

      controller.dispose();
    });

    test('Corner resize snaps both width and height to multiples', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 800);

      final w = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W',
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

      w.currentWidth = 285;
      w.currentHeight = 190;
      w.snapResize(corner: CornerSide.bottomRight);
      expect(w.currentWidth, 300.0);
      expect(w.currentHeight, 200.0);

      controller.dispose();
    });

    test('Window position snaps to grid of minWidth and minHeight', () {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 800);

      final w = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W',
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

      // 1. Both X and Y within snapRange (100 is multiple of 100; x=190->200, y=205->200)
      w.x = 190;
      w.y = 205;
      w.snapWindowPosition();
      expect(w.x, 200.0);
      expect(w.y, 200.0);

      // 2. Outside snapRange (x=250 is 50px away from 200 and 300) -> does not snap
      w.x = 250;
      w.y = 205;
      w.snapWindowPosition();
      expect(w.x, 250.0);
      expect(w.y, 205.0);

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

    testWidgets('Window dragging: updates coordinates smoothly with 1:1 hardware mouse alignment and device-pixel precision', (
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
          x: 100,
          y: 100,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.amber),
      );

      await tester.pumpAndSettle();

      expect(w1.x, 100.0);
      expect(w1.y, 100.0);
      expect(w1.visualX, 100.0);
      expect(w1.visualY, 100.0);

      // Start drag gesture
      final gesture = await tester.startGesture(
        tester.getCenter(find.byWidget(w1.widget)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move by 30, 40
      await gesture.moveBy(const Offset(30, 40));
      await tester.pump();

      // During active drag: coordinates x and y update smoothly with 1:1 mouse tracking
      expect(w1.x, 130.0);
      expect(w1.y, 140.0);
      expect(w1.visualX, 130.0);
      expect(w1.visualY, 140.0);

      // Move by another 20, 10
      await gesture.moveBy(const Offset(20, 10));
      await tester.pump();

      expect(w1.x, 150.0);
      expect(w1.y, 150.0);
      expect(w1.visualX, 150.0);
      expect(w1.visualY, 150.0);

      // Finish drag
      await gesture.up();
      await tester.pumpAndSettle();

      expect(w1.x, 150.0);
      expect(w1.y, 150.0);
      expect(w1.visualX, 150.0);
      expect(w1.visualY, 150.0);

      controller.dispose();
    });

    testWidgets('Custom RenderBox WindowResizeFrame: edge and corner handle hit testing and mouse cursors', (
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
        parameter: const ParameterWindow(
          title: 'W1',
          id: '1',
          x: 100,
          y: 100,
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      // Find the WindowResizeFrame render box
      final resizeFrameFinder = find.byType(WindowResizeFrame);
      expect(resizeFrameFinder, findsOneWidget);
      final RenderWindowResizeFrame renderBox =
          tester.renderObject(resizeFrameFinder);
      final double w = renderBox.size.width;
      final double h = renderBox.size.height;

      // Test corner hit-testing
      final topLeftHit = BoxHitTestResult();
      renderBox.hitTest(topLeftHit, position: const Offset(2, 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpLeftDownRight);

      final topRightHit = BoxHitTestResult();
      renderBox.hitTest(topRightHit, position: Offset(w - 2, 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpRightDownLeft);

      final bottomLeftHit = BoxHitTestResult();
      renderBox.hitTest(bottomLeftHit, position: Offset(2, h - 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpRightDownLeft);

      final bottomRightHit = BoxHitTestResult();
      renderBox.hitTest(bottomRightHit, position: Offset(w - 2, h - 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpLeftDownRight);

      // Test edge hit-testing
      final rightEdgeHit = BoxHitTestResult();
      renderBox.hitTest(rightEdgeHit, position: Offset(w - 2, h / 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeLeftRight);

      final bottomEdgeHit = BoxHitTestResult();
      renderBox.hitTest(bottomEdgeHit, position: Offset(w / 2, h - 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpDown);

      final leftEdgeHit = BoxHitTestResult();
      renderBox.hitTest(leftEdgeHit, position: Offset(1, h / 2));
      expect(renderBox.cursor, SystemMouseCursors.resizeLeftRight);

      final topEdgeHit = BoxHitTestResult();
      renderBox.hitTest(topEdgeHit, position: Offset(w / 2, 1));
      expect(renderBox.cursor, SystemMouseCursors.resizeUpDown);

      // Center (non-handle) hit-testing delegates to child and does not set resize cursor
      final centerHit = BoxHitTestResult();
      renderBox.hitTest(centerHit, position: Offset(w / 2, h / 2));
      expect(renderBox.cursor, MouseCursor.defer);

      controller.dispose();
    });

    testWidgets('Custom RenderBox WindowResizeFrame: dragging edge resizes window geometry', (
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
          x: 100,
          y: 100,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.green),
      );

      await tester.pumpAndSettle();

      final resizeFrameFinder = find.byType(WindowResizeFrame);
      final windowTopRight = tester.getTopRight(resizeFrameFinder);

      // Drag right edge (slightly inward from top right, e.g. at middle height of right edge)
      final rightEdgePoint = Offset(windowTopRight.dx - 1, windowTopRight.dy + 100);

      final resizeGesture = await tester.startGesture(
        rightEdgePoint,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Drag outward by 50px
      await resizeGesture.moveBy(const Offset(50, 0));
      await tester.pumpAndSettle();

      await resizeGesture.up();
      await tester.pumpAndSettle();

      // Window should now be wider (200 + 50 = 250)
      expect(w1.currentWidth, 250.0);
      expect(w1.currentHeight, 200.0);

      controller.dispose();
    });

    testWidgets('MdiManager moves focus to unfocused window when dragging from its header', (
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
          x: 50,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.red),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 300,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      // W2 should currently have focus
      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);
      expect(w2.hasFocus, true);

      // Drag unfocused window W1 by its header title text
      final w1TitleFinder = find.descendant(
        of: find.byWidget(w1.widget),
        matching: find.text('W1'),
      );
      expect(w1TitleFinder, findsOneWidget);

      await tester.drag(w1TitleFinder, const Offset(40, 40), kind: PointerDeviceKind.mouse, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Focus must now belong to W1!
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(w2.hasFocus, false);
      expect(w1.x, greaterThan(50.0));
      expect(w1.y, greaterThan(50.0));

      controller.dispose();
    });

    testWidgets('MdiManager moves focus to unfocused window when dragging its body while hovered', (
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
          x: 50,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.red),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 300,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);
      expect(w2.hasFocus, true);

      // Simulate mouse hovering over W1 body
      final w1Center = tester.getCenter(find.byWidget(w1.widget));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      // Hover over W1
      await gesture.moveTo(w1Center);
      await tester.pumpAndSettle();

      // Ensure W1 is hovered but not yet focused
      expect(w1.isHovered, true);
      expect(w1.hasFocus, false);

      // Remove the hover test pointer before starting a fresh drag
      await gesture.removePointer();
      await tester.pump();

      // Drag W1 body while unfocused
      await tester.dragFrom(w1Center, const Offset(40, 40), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      // Focus must now belong to W1!
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(w2.hasFocus, false);
      expect(w1.x, greaterThan(50.0));
      expect(w1.y, greaterThan(50.0));

      controller.dispose();
    });

    testWidgets('MdiManager transfers focus immediately on pointer down when clicking an unfocused window', (
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
          x: 50,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.red),
      );

      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'W2',
          id: '2',
          x: 300,
          y: 50,
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.blue),
      );

      await tester.pumpAndSettle();

      expect(controller.frontWindow, w2);
      expect(w1.hasFocus, false);
      expect(w2.hasFocus, true);

      // Press mouse button down on unfocused W1 without releasing (no tap up!)
      final w1Center = tester.getCenter(find.byWidget(w1.widget));
      final gesture = await tester.startGesture(w1Center, kind: PointerDeviceKind.mouse);
      await tester.pump();

      // Focus must have transferred immediately on pointer down without any delay!
      expect(controller.frontWindow, w1);
      expect(w1.hasFocus, true);
      expect(w2.hasFocus, false);

      await gesture.up();
      await tester.pumpAndSettle();

      controller.dispose();
    });

    testWidgets('Window dragging under 170% zoom/scale tracks mouse cursor 1:1 in device coordinates', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 1000);

      const double zoomScale = 1.7;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Transform.scale(
              scale: zoomScale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1000,
                height: 1000,
                child: MdiManager(controller: controller),
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
          currentWidth: 200,
          currentHeight: 200,
        ),
        child: (c) => Container(color: Colors.amber),
      );

      await tester.pumpAndSettle();

      expect(w1.x, 100.0);
      expect(w1.y, 100.0);

      // Start drag from center of window W1
      final w1Center = tester.getCenter(find.byWidget(w1.widget));
      final gesture = await tester.startGesture(
        w1Center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move mouse pointer by 170 physical/device pixels in X and Y
      // Under 1.7 scale, 170 device pixels = 100 canvas/virtual pixels.
      await gesture.moveBy(const Offset(170, 170));
      await tester.pump();

      // Window position in canvas coordinates must be 100 + 100 = 200 (not 100 + 170 = 270!)
      expect(w1.x, closeTo(200.0, 0.001));
      expect(w1.y, closeTo(200.0, 0.001));

      // Move mouse pointer by another 85 physical/device pixels (85 / 1.7 = 50 canvas pixels)
      await gesture.moveBy(const Offset(85, 85));
      await tester.pump();

      expect(w1.x, closeTo(250.0, 0.001));
      expect(w1.y, closeTo(250.0, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(w1.x, closeTo(250.0, 0.001));
      expect(w1.y, closeTo(250.0, 0.001));

      controller.dispose();
    });

    testWidgets('Window dragging under FittedBox zoom (neo_online_trading pattern) tracks mouse 1:1', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1700,
                height: 1700,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 1000,
                    height: 1000,
                    child: MdiManager(controller: controller),
                  ),
                ),
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
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.amber),
      );

      await tester.pumpAndSettle();

      final w1Center = tester.getCenter(find.byWidget(w1.widget));
      final gesture = await tester.startGesture(
        w1Center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Move 170 physical pixels (which corresponds to 100 virtual canvas units)
      await gesture.moveBy(const Offset(170, 170));
      await tester.pump();

      expect(w1.x, closeTo(200.0, 0.001));
      expect(w1.y, closeTo(200.0, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();

      controller.dispose();
    });

    testWidgets('Window resizing under 170% zoom/scale tracks mouse cursor 1:1 in device coordinates', (
      WidgetTester tester,
    ) async {
      final controller = MdiController();
      controller.init();
      controller.screenSize = const Size(1000, 1000);

      const double zoomScale = 1.7;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Transform.scale(
              scale: zoomScale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1000,
                height: 1000,
                child: MdiManager(controller: controller),
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
          currentWidth: 200,
          currentHeight: 200,
          minWidth: 100,
          minHeight: 100,
        ),
        child: (c) => Container(color: Colors.amber),
      );

      await tester.pumpAndSettle();

      final resizeFrameFinder = find.byType(WindowResizeFrame);
      expect(resizeFrameFinder, findsOneWidget);

      final resizeBox = tester.renderObject(resizeFrameFinder) as RenderBox;
      final rightEdgeLocal = Offset(resizeBox.size.width - 2, resizeBox.size.height / 2);
      final rightEdgeGlobal = resizeBox.localToGlobal(rightEdgeLocal);

      final gesture = await tester.startGesture(
        rightEdgeGlobal,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      // Drag right edge outward by 85 physical pixels (85 / 1.7 = 50 canvas units)
      await gesture.moveBy(const Offset(85, 0));
      await tester.pump();

      expect(w1.currentWidth, closeTo(250.0, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(w1.currentWidth, closeTo(250.0, 0.001));

      controller.dispose();
    });
  });

  group('MdiShortcutConfiguration Tests', () {
    test('Default values and presets are populated correctly', () {
      final config = MdiShortcutConfiguration.desktop;
      expect(config.enabled, isTrue);
      expect(config.closeWindow.isNotEmpty, isTrue);
      expect(config.focusNext.isNotEmpty, isTrue);
      expect(config.focusPrevious.isNotEmpty, isTrue);
      expect(config.moveLeft.isNotEmpty, isTrue);
      expect(config.moveRight.isNotEmpty, isTrue);
      expect(config.moveUp.isNotEmpty, isTrue);
      expect(config.moveDown.isNotEmpty, isTrue);
      expect(config.moveStepX, isNull);
      expect(config.moveStepY, isNull);

      final none = MdiShortcutConfiguration.none;
      expect(none.enabled, isFalse);
      expect(none.closeWindow.isEmpty, isTrue);
      expect(none.moveRight.isEmpty, isTrue);

      final web = MdiShortcutConfiguration.web;
      expect(web.enabled, isTrue);
      expect(web.closeWindow.isNotEmpty, isTrue);
    });

    test('copyWith properly overrides fields while preserving others', () {
      final initial = MdiShortcutConfiguration.desktop;
      final modified = initial.copyWith(
        moveStepX: 75.0,
        moveStepY: 85.0,
        enabled: false,
        closeWindow: const [SingleActivator(LogicalKeyboardKey.keyQ, control: true)],
      );

      expect(modified.enabled, isFalse);
      expect(modified.moveStepX, 75.0);
      expect(modified.moveStepY, 85.0);
      expect(modified.closeWindow.length, 1);
      expect(modified.focusNext, equals(initial.focusNext));
      expect(modified.moveLeft, equals(initial.moveLeft));

      // Test clearing moveStepX back to null
      final reset = modified.copyWith(moveStepX: null);
      expect(reset.moveStepX, isNull);
      expect(reset.moveStepY, 85.0);
    });

    test('Equality and hashCode work as expected', () {
      final a = MdiShortcutConfiguration.desktop;
      final b = MdiShortcutConfiguration.desktop;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = a.copyWith(enabled: false);
      expect(a, isNot(equals(c)));
    });

    testWidgets('Default shortcuts: Ctrl+Alt+Shift+Arrow moves window by minWidth/minHeight', (tester) async {
      final controller = MdiController();
      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          id: '1',
          title: 'W1',
          x: 0,
          y: 0,
          minWidth: 100,
          minHeight: 50,
        ),
        child: (_) => const SizedBox(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MdiManager(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      expect(w1.x, 0.0);
      expect(w1.y, 0.0);

      // Move right: Ctrl + Alt + Shift + ArrowRight
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(w1.x, 100.0);
      expect(w1.y, 0.0);

      // Move down: Ctrl + Alt + Shift + ArrowDown
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(w1.x, 100.0);
      expect(w1.y, 50.0);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      controller.dispose();
    });

    testWidgets('Custom moveStepX and moveStepY override default grid step distance', (tester) async {
      final controller = MdiController(
        shortcuts: MdiShortcutConfiguration.desktop.copyWith(
          moveStepX: 42.0,
          moveStepY: 33.0,
        ),
      );
      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          id: '1',
          title: 'W1',
          x: 0,
          y: 0,
          minWidth: 100,
          minHeight: 50,
        ),
        child: (_) => const SizedBox(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MdiManager(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(w1.x, 42.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(w1.y, 33.0);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      controller.dispose();
    });

    testWidgets('MdiShortcutConfiguration.none disables all shortcuts', (tester) async {
      final controller = MdiController(
        shortcuts: MdiShortcutConfiguration.none,
      );
      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          id: '1',
          title: 'W1',
          x: 0,
          y: 0,
          minWidth: 100,
          minHeight: 50,
        ),
        child: (_) => const SizedBox(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MdiManager(controller: controller),
        ),
      ));
      await tester.pumpAndSettle();

      // Attempt to move window
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(w1.x, 0.0); // Did not move

      // Attempt to close window (Ctrl+W)
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.windows.length, 1); // Not closed

      controller.dispose();
    });

    testWidgets('Custom shortcut overrides: Alt+Arrow moves, Ctrl+Q closes', (tester) async {
      final customShortcuts = MdiShortcutConfiguration(
        moveRight: const [SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)],
        closeWindow: const [SingleActivator(LogicalKeyboardKey.keyQ, control: true)],
        moveStepX: 60.0,
      );

      final controller = MdiController();
      final w1 = controller.addWindow(
        parameter: const ParameterWindow(
          id: '1',
          title: 'W1',
          x: 0,
          y: 0,
          minWidth: 100,
          minHeight: 50,
        ),
        child: (_) => const SizedBox(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MdiManager(
            controller: controller,
            shortcuts: customShortcuts,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Test custom move: Alt + ArrowRight
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(w1.x, 60.0);

      // Old shortcut Ctrl+W should NOT close
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(controller.windows.length, 1);

      // New custom shortcut Ctrl+Q should close
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.windows.isEmpty, isTrue);

      controller.dispose();
    });
  });

  group('MdiDimensions Tests', () {
    tearDown(() {
      MdiDimensions.resetGlobal();
    });

    test('Defaults fallback constants match 382x474 and 382x119', () {
      expect(MdiDimensions.defaults.defaultWidth, 382.0);
      expect(MdiDimensions.defaults.defaultHeight, 474.0);
      expect(MdiDimensions.defaults.defaultMinWidth, 382.0);
      expect(MdiDimensions.defaults.defaultMinHeight, 119.0);

      // Deprecated standard alias points to defaults
      expect(MdiDimensions.standard, MdiDimensions.defaults);
    });

    test('MdiDimensions copyWith and equality work correctly', () {
      const original = MdiDimensions(
        width: 400,
        height: 500,
        minWidth: 300,
        minHeight: 150,
      );
      final modified = original.copyWith(width: 450);

      expect(modified.defaultWidth, 450.0);
      expect(modified.defaultHeight, 500.0);
      expect(modified.defaultMinWidth, 300.0);
      expect(modified.defaultMinHeight, 150.0);

      expect(original == original.copyWith(), isTrue);
      expect(original.hashCode == original.copyWith().hashCode, isTrue);
      expect(original == modified, isFalse);
    });

    test('Direct static properties MdiDimensions.width and height work cleanly', () {
      // Initial state
      expect(MdiDimensions.width, 382.0);
      expect(MdiDimensions.height, 474.0);
      expect(MdiDimensions.minWidth, 382.0);
      expect(MdiDimensions.minHeight, 119.0);

      // Direct assignment at class level
      MdiDimensions.width = 500.0;
      MdiDimensions.height = 600.0;
      MdiDimensions.minWidth = 350.0;
      MdiDimensions.minHeight = 200.0;

      expect(MdiDimensions.width, 500.0);
      expect(MdiDimensions.height, 600.0);
      expect(MdiDimensions.minWidth, 350.0);
      expect(MdiDimensions.minHeight, 200.0);

      // Legacy ParameterWindow getters dynamically reflect the new values
      expect(ParameterWindow.defaultWidth, 500.0);
      expect(ParameterWindow.defaultHeight, 600.0);
      expect(ParameterWindow.defaultMinWidth, 350.0);
      expect(ParameterWindow.defaultMinHeight, 200.0);

      // Windows created without dimensions automatically use the direct values
      const window = ParameterWindow(title: 'Auto Window', id: 'auto-1');
      expect(window.currentWidth, 500.0);
      expect(window.currentHeight, 600.0);
      expect(window.minWidth, 350.0);
      expect(window.minHeight, 200.0);

      // Reset restores defaults
      MdiDimensions.resetGlobal();
      expect(MdiDimensions.width, 382.0);
      expect(MdiDimensions.height, 474.0);
    });

    test('MdiDimensions.configure updates dimensions incrementally', () {
      MdiDimensions.configure(width: 420.0);
      expect(MdiDimensions.width, 420.0);
      expect(MdiDimensions.height, 474.0); // Preserved

      MdiDimensions.configure(height: 520.0);
      expect(MdiDimensions.width, 420.0); // Preserved
      expect(MdiDimensions.height, 520.0);
    });

    test('MdiController with custom dynamic dimensions resolves windows', () {
      final customDimensions = const MdiDimensions(
        width: 550.0,
        height: 650.0,
        minWidth: 400.0,
        minHeight: 250.0,
      );

      final controller = MdiController(dimensions: customDimensions);

      // Add window without explicit dimensions
      final w1 = controller.addWindow(
        parameter: const ParameterWindow(title: 'Doc', id: '1'),
        child: (_) => const SizedBox(),
      );

      // Window controller receives resolved dimensions from controller
      expect(w1.currentWidth, 550.0);
      expect(w1.currentHeight, 650.0);
      expect(w1.minWidth, 400.0);
      expect(w1.minHeight, 250.0);

      // Add window with explicit dimension override
      final w2 = controller.addWindow(
        parameter: const ParameterWindow(
          title: 'Custom Doc',
          id: '2',
          currentWidth: 300.0,
        ),
        child: (_) => const SizedBox(),
      );

      expect(w2.currentWidth, 300.0); // Explicit override kept
      expect(w2.currentHeight, 650.0); // Inherited from controller

      controller.dispose();
    });

    test('ParameterWindow getWidthScale and getHeightScale use dynamic dimensions', () {
      const custom = MdiDimensions(width: 500, height: 600);

      // Standard scale
      expect(ParameterWindow.getWidthScale(1000), 2); // 1006 ~/ 382 = 2
      expect(ParameterWindow.getHeightScale(1200), 2); // 1206 ~/ 474 = 2

      // Custom scale passed directly
      expect(ParameterWindow.getWidthScale(1000, custom), 2); // 1006 ~/ 500 = 2
      expect(ParameterWindow.getWidthScale(400, custom), 1); // 406 ~/ 500 = 0 -> clamped to 1
      expect(ParameterWindow.getHeightScale(500, custom), 0); // 506 ~/ 600 = 0
    });
  });
}
