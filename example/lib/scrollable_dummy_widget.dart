import 'package:flutter/material.dart';
import 'package:mdi_view/mdi_view.dart';

class ScrollableDummyWidget extends StatefulWidget {
  const ScrollableDummyWidget({super.key});

  @override
  State<ScrollableDummyWidget> createState() => _ScrollableDummyWidgetState();
}

class _ScrollableDummyWidgetState extends State<ScrollableDummyWidget> {

  late final ScrollController _scrollController;

  @override
  void initState() {
    _scrollController = ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final ctrl = ResizableWindowProvider.of(context);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header / Instruction within the window
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scrollable Window Content',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dragging over this scrollable list below will scroll the list rather than moving the window. Try it!',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
    
          // Scrollable List
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: 100,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  return Material(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                        child: Text('${index + 1}'),
                      ),
                      title: Text('Scrollable Item ${index + 1}'),
                      subtitle: Text('Details for item description number ${index + 1}'),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tapped Item ${index + 1}'),
                            duration: const Duration(milliseconds: 500),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
    
          // Actions at bottom
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => ctrl?.close(),
                  child: const Text('Close Window'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
