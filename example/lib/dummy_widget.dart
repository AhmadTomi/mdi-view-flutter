import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mdi_view/mdi_view.dart';

class DummyWidget extends StatefulWidget {
  const DummyWidget({super.key});

  @override
  State<DummyWidget> createState() => _DummyWidgetState();
}

class _DummyWidgetState extends State<DummyWidget> {
  FocusNode focusNode = FocusNode();

  bool isFocused = false;

  ResizeableWindowController? controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    /*controller?.focusNotifier.removeListener(() {
      focusChecking(false);
    });*/
    super.dispose();
  }

  void focusChecking(bool value) {
    if (value != isFocused) {
      isFocused = value;
      if (isFocused) {
        focusNode.requestFocus();
      }
    }
  }

  bool _onKeyEvent(KeyEvent) {
    if (!isFocused) return false;
    if (KeyEvent is! KeyDownEvent) return false;
    if (KeyEvent.logicalKey == LogicalKeyboardKey.f2) {
      if (mounted) {
        setState(() {
          print("HIT F2");
        });
      }
    }
    if (KeyEvent.logicalKey == LogicalKeyboardKey.f4) {
      print("HIT F4");
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ResizableWindowProvider.of(context);
    if (ctrl != null) {
      focusChecking(ctrl.hasFocus);
    }

    ctrl?.onKeyEvent = _onKeyEvent;

    return Column(
      children: [
        ctrl?.dragWidget(
              child: Container(
                color: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 30,
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${ctrl.tag}",
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      onPressed: () => ctrl.close(), // Close button
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ) ??
            const SizedBox(),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topLeft,
            width: double.infinity, // Ensure it fills the space
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '''
                      ${ctrl?.tag} Lorem Ipsum is simply dummy text...
                                  ''',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextFormField(focusNode: focusNode),
                  // If you need the controller (e.g., for a button):
                  TextButton(
                    onPressed: () {
                      // This is how you access the controller now!
                      ctrl?.close();
                    },
                    child: const Text("Close from inside"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    // If a timer is already active, cancel it
    if (_timer != null) {
      _timer!.cancel();
    }

    // Start a new timer
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
