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
        throwsException,
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
}
