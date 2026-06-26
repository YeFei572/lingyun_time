import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme_controller.dart';
import '../../baby_log/presentation/baby_log_controller.dart';
import '../../time_silhouette/data/s3_storage_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeaderCard(),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出备份'),
                  subtitle: const Text('将本地行为记录导出为 txt'),
                  onTap: () async {
                    final text = await ref.read(babyLogControllerProvider.notifier).exportTxt();
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('导出内容'),
                        content: SingleChildScrollView(child: SelectableText(text)),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从 txt 导入行为记录'),
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['txt'],
                      withData: true,
                    );
                    final file = result?.files.single;
                    final bytes = file?.bytes;
                    if (bytes == null) return;
                    await ref.read(babyLogControllerProvider.notifier).importTxt(
                          String.fromCharCodes(bytes),
                        );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.dark_mode),
                  title: Text('主题模式'),
                  subtitle: Text('在白天模式和暗夜模式之间切换'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final mode = ref.watch(themeModeProvider);
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('白天')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('暗夜')),
                        ],
                        selected: {mode},
                        onSelectionChanged: (value) {
                          ref.read(themeModeProvider.notifier).state = value.first;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('S3 上传配置'),
              subtitle: const Text('当前为 Mock 实现，后续可接入真实 S3'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('S3 配置'),
                    content: Text('目前使用 MockS3StorageService，后续可在这里扩展访问密钥、endpoint 和 bucket。'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('工具与备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('把导入导出、存储配置统一收进设置页，主页面只负责记录与浏览。'),
        ],
      ),
    );
  }
}
