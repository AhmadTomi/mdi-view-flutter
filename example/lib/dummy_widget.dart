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

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      alignment: Alignment.topLeft,
      width: double.infinity, // Ensure it fills the space
      height: double.infinity,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '''${ctrl?.tag} Lorem Ipsum is simply dummy text...''',
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
            ElevatedButton(onPressed: (){
              showDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (context) {
                return AlertDialog(
                  // To display the title it is optional
                  title: Text('Welcome'),
                  // Message which will be pop up on the screen
                  content: Text('GeeksforGeeks'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('ACCEPT'),
                    ),
                  ],
                );
              });
            }, child: Text("Show Dialog"))
          ],
        ),
      ),
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
