import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mdi_view/mdi_view.dart';

import 'dummy_widget.dart';
import 'calculator_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter MDI Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MdiController controller = MdiController();
  List<Map<String, dynamic>>? _savedLayout;
  int count = 1;

  @override
  void initState() {
    controller.init();
    super.initState();
    
    // Pre-populate canvas on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addInitialWindows();
    });
  }

  void _addInitialWindows() {
    controller.addWindow(
      parameter: const ParameterWindow(
        title: 'Calculator 1',
        id: 'calc-init',
        x: 40,
        y: 40,
        currentWidth: 260,
        currentHeight: 350,
        minWidth: 200,
        minHeight: 300,
      ),
      child: (controller) => const CalculatorWidget(),
    );

    controller.addWindow(
      parameter: const ParameterWindow(
        title: 'Document 1',
        id: 'doc-init',
        x: 320,
        y: 60,
        currentWidth: 400,
        currentHeight: 300,
      ),
      child: (controller) => const DummyWidget(),
    );
  }

  void _addTextWindow() {
    controller.addWindow(
      parameter: ParameterWindow(
        title: 'Document $count',
        id: 'doc-$count',
      ),
      child: (controller) => const DummyWidget(),
    );
    count++;
  }

  void _addCalculatorWindow() {
    controller.addWindow(
      parameter: ParameterWindow(
        title: 'Calculator $count',
        id: 'calc-$count',
        currentWidth: 260,
        currentHeight: 350,
        minWidth: 200,
        minHeight: 300,
      ),
      child: (controller) => const CalculatorWidget(),
    );
    count++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter MDI Enterprise Demo', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.blue.shade900,
        elevation: 2,
      ),
      body: Row(
        children: [
          Container(
            width: 290,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CONTROL PANEL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  // Add Windows Section
                  ElevatedButton.icon(
                    onPressed: _addTextWindow,
                    icon: const Icon(Icons.note_add, size: 18),
                    label: const Text('Add Text Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addCalculatorWindow,
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Add Calculator'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'LAYOUT PERSISTENCE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _savedLayout = controller.exportLayout();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Workspace layout exported and saved to memory!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Save Layout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(color: Colors.blue.shade800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _savedLayout == null
                        ? null
                        : () {
                            controller.importLayout(
                              _savedLayout!,
                              childBuilder: (param) {
                                if (param.title.startsWith('Calculator')) {
                                  return const CalculatorWidget();
                                }
                                return const DummyWidget();
                              },
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Layout restored via state reconciliation!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restore Layout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(color: _savedLayout == null ? Colors.grey : Colors.blue.shade800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.removeAllWindows();
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear Canvas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade900,
                      side: BorderSide(color: Colors.red.shade900),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Shortcuts Section
                  Card(
                    elevation: 0,
                    color: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.keyboard, size: 18, color: Colors.blueGrey),
                              SizedBox(width: 8),
                              Text('Shortcuts Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 16),
                          if (kIsWeb) ...[
                            _buildShortcutRow('Ctrl + .', 'Next window'),
                            _buildShortcutRow('Ctrl + ,', 'Prev window'),
                            _buildShortcutRow('Alt + W', 'Close window'),
                          ] else ...[
                            _buildShortcutRow('Ctrl + Tab', 'Next window'),
                            _buildShortcutRow('Ctrl + Shift + Tab', 'Prev window'),
                            _buildShortcutRow('Ctrl + W / F4', 'Close window'),
                          ],
                          _buildShortcutRow('Ctrl + Alt + Arrows', 'Move / Cycle'),
                          const Divider(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.align_horizontal_left, size: 18, color: Colors.blueGrey),
                              SizedBox(width: 8),
                              Text('Edge Snapping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Drag windows or resize their edges near other windows or canvas borders (within 12px) to snap them flush.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // MDI Canvas
          Expanded(
            child: MdiManager(
              controller: controller,
              style: MdiStyleConfiguration(
                borderRadius: 4,
                gap: 1,
                tabMenuMinWidth: 60,
                unfocusBlockerColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(keys, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          Text(action, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
