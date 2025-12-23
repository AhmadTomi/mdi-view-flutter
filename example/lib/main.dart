import 'package:flutter/material.dart';
import 'package:mdi_view/mdi_view.dart';

import 'dummy_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter MDI Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
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

  int count = 1;

  @override
  void initState() {
    controller.init();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= 600) {
      return Scaffold(backgroundColor: Colors.white60, body: TextFormField());
    }
    return Scaffold(
      backgroundColor: Colors.white60,
      body: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: MenuBar(
                  children: <Widget>[
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Widget A',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Widget&A'),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Widget B',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Widget&B'),
                        ),
                      ],
                      child: const MenuAcceleratorLabel('&Menu1'),
                    ),
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Widget C',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Widget&C'),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Widget D',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Widget&D'),
                        ),
                      ],
                      child: const MenuAcceleratorLabel('&Menu2'),
                    ),
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Template A',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Template &A'),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            controller.addWindow(
                              parameter: ParameterWindow(
                                title: 'Widget D',
                                id: count.toString(),
                              ),
                              child: (controller) => DummyWidget(),
                            );
                            count++;
                          },
                          child: const MenuAcceleratorLabel('Widget&D'),
                        ),
                      ],
                      child: const MenuAcceleratorLabel('&Template'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
}
