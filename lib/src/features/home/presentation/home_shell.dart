import 'package:flutter/material.dart';

import '../../baby_log/presentation/baby_log_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../time_silhouette/presentation/time_silhouette_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const BabyLogPage(),
      const TimeSilhouettePage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.favorite), label: '行为记录'),
          NavigationDestination(icon: Icon(Icons.photo_library), label: '时光剪影'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
