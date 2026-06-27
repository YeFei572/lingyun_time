import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
  final visitedIndexes = <int>{0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: List.generate(3, _buildTabPage),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
            visitedIndexes.add(value);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(HugeIcons.strokeRoundedBaby02),
            label: '行为记录',
          ),
          NavigationDestination(icon: Icon(Icons.photo_library), label: '时光剪影'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildTabPage(int pageIndex) {
    if (!visitedIndexes.contains(pageIndex)) {
      // 未访问的页面先不挂载，避免首帧阶段同时触发多个 Tab 的构建和本地数据读取。
      return const SizedBox.shrink();
    }

    return switch (pageIndex) {
      0 => const BabyLogPage(),
      1 => const TimeSilhouettePage(),
      2 => const SettingsPage(),
      _ => const SizedBox.shrink(),
    };
  }
}
