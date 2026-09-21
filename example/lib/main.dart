import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mdi_view/mdi_view.dart';

import 'dummy_widget.dart';
import 'calculator_widget.dart';
import 'scrollable_dummy_widget.dart';

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
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MdiController controller = MdiController();
  List<Map<String, dynamic>>? _savedLayout;
  int count = 1;

  double _zoomScale = 1.0;
  static const List<double> _presetScales = [0.75, 1.0, 1.25, 1.5, 1.7, 2.0];

  void _setZoom(double scale) {
    setState(() {
      _zoomScale = double.parse(scale.clamp(0.5, 2.5).toStringAsFixed(2));
    });
  }

  void _zoomIn() {
    _setZoom(_zoomScale + 0.1);
  }

  void _zoomOut() {
    _setZoom(_zoomScale - 0.1);
  }

  void _resetZoom() {
    _setZoom(1.0);
  }

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

  void _addScrollableWindow() {
    controller.addWindow(
      parameter: ParameterWindow(
        title: 'Scrollable List $count',
        id: 'scroll-$count',
        currentWidth: 350,
        currentHeight: 450,
        minWidth: 250,
        minHeight: 300,
      ),
      child: (controller) => const ScrollableDummyWidget(),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _zoomScale == 1.7 ? Colors.amber.shade700 : Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Zoom: ${(_zoomScale * 100).toInt()}% (FittedBox)',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addScrollableWindow,
                    icon: const Icon(Icons.format_list_bulleted, size: 18),
                    label: const Text('Add Scrollable Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Zoom & Scale Mechanism (FittedBox)
                  const Text(
                    'ZOOM MECHANISM (FittedBox)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _zoomScale > 0.5 ? _zoomOut : null,
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              tooltip: 'Zoom Out (-10%)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: _zoomScale == 1.7
                                      ? Colors.amber.shade100
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _zoomScale == 1.7
                                        ? Colors.amber.shade700
                                        : Colors.blue.shade200,
                                  ),
                                ),
                                child: Text(
                                  '${(_zoomScale * 100).toInt()}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _zoomScale == 1.7
                                        ? Colors.amber.shade900
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _zoomScale < 2.5 ? _zoomIn : null,
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              tooltip: 'Zoom In (+10%)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: _zoomScale != 1.0 ? _resetZoom : null,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Reset', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _zoomScale,
                            min: 0.5,
                            max: 2.5,
                            divisions: 20,
                            label: '${(_zoomScale * 100).toInt()}%',
                            onChanged: _setZoom,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _presetScales.map((scale) {
                            final percent = (scale * 100).toInt();
                            final isSelected = (_zoomScale - scale).abs() < 0.01;
                            return ChoiceChip(
                              label: Text(
                                '$percent%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? (scale == 1.7 ? Colors.amber.shade900 : Colors.blue.shade900)
                                      : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: scale == 1.7 ? Colors.amber.shade300 : Colors.blue.shade200,
                              onSelected: (_) => _setZoom(scale),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            );
                          }).toList(),
                        ),
                      ],
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
                                if (param.title.startsWith('Scrollable List')) {
                                  return const ScrollableDummyWidget();
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

          // MDI Canvas with FittedBox Zoom Mechanism
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final physicalSize = constraints.biggest;
                final virtualSize = physicalSize / _zoomScale;

                return ClipRect(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: virtualSize,
                      devicePixelRatio:
                          MediaQuery.of(context).devicePixelRatio * _zoomScale,
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: virtualSize.width,
                        height: virtualSize.height,
                        child: MdiManager(
                          controller: controller,
                          style: MdiStyleConfiguration(
                            borderRadius: 4,
                            gap: 1,
                            tabMenuMinWidth: 60,
                            unfocusBlockerColor: Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
