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
      expect(find.text(windowTitle), findsOneWidget); // In tab bar
      expect(find.text('Window Content'), findsOneWidget); // Content

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
  });
}
