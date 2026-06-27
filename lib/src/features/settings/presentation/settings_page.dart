import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme_controller.dart';
import '../../baby_log/presentation/baby_log_controller.dart';
import '../../time_silhouette/domain/s3_upload_config.dart';
import '../../time_silhouette/presentation/s3_config_controller.dart';
import '../../time_silhouette/presentation/time_silhouette_controller.dart';
import '../data/backup_repository_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s3ConfigState = ref.watch(s3ConfigControllerProvider);
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
                  subtitle: const Text('导出行为记录、时光剪影和 S3 配置，请妥善保管'),
                  onTap: () => _exportBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从 txt 恢复全部本地数据'),
                  onTap: () => _importBackup(context, ref),
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
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('白天'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('暗夜'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (value) {
                          ref.read(themeModeProvider.notifier).state =
                              value.first;
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
              subtitle: Text(
                s3ConfigState.maybeWhen(
                  data: (config) {
                    if (config.isConfigured) {
                      return '${config.bucket} · ${config.endpoint}';
                    }
                    return '未配置，照片和视频暂时无法上传';
                  },
                  orElse: () => '正在读取配置',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final currentConfig = await ref.read(
                  s3ConfigControllerProvider.future,
                );
                if (!context.mounted) return;
                final nextConfig = await showDialog<S3UploadConfig>(
                  context: context,
                  builder: (_) => _S3ConfigDialog(initialConfig: currentConfig),
                );
                if (nextConfig == null) return;
                await ref
                    .read(s3ConfigControllerProvider.notifier)
                    .saveConfig(nextConfig);
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('S3 配置已保存')));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final backupRepository = await ref.read(backupRepositoryProvider.future);
      final content = await backupRepository.exportTxt();
      final fileName =
          'lingyun_time_backup_'
          '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.txt';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出凌云时光备份',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: _encodeBackupTxt(content),
      );

      if (!context.mounted) {
        return;
      }
      if (savedPath == null && !kIsWeb) {
        messenger.showSnackBar(const SnackBar(content: Text('已取消导出')));
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('备份文件已导出')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('导入备份'),
          content: const Text('导入后会覆盖当前行为记录、时光剪影和 S3 配置，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('继续导入'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }

      final backupRepository = await ref.read(backupRepositoryProvider.future);
      await backupRepository.importTxt(utf8.decode(bytes));
      ref
        ..invalidate(babyLogControllerProvider)
        ..invalidate(timeSilhouetteControllerProvider)
        ..invalidate(s3ConfigControllerProvider);

      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('备份已导入')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  Uint8List _encodeBackupTxt(String content) {
    // 写入 UTF-8 BOM，提升系统文件查看器对中文备份内容的编码识别成功率。
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
  }
}

class _S3ConfigDialog extends StatefulWidget {
  const _S3ConfigDialog({required this.initialConfig});

  final S3UploadConfig initialConfig;

  @override
  State<_S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<_S3ConfigDialog> {
  late final TextEditingController endpointController;
  late final TextEditingController regionController;
  late final TextEditingController bucketController;
  late final TextEditingController accessKeyController;
  late final TextEditingController secretKeyController;
  late final TextEditingController pathPrefixController;
  late final TextEditingController publicBaseUrlController;
  late bool usePathStyle;
  var obscureSecret = true;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    endpointController = TextEditingController(text: config.endpoint);
    regionController = TextEditingController(text: config.region);
    bucketController = TextEditingController(text: config.bucket);
    accessKeyController = TextEditingController(text: config.accessKeyId);
    secretKeyController = TextEditingController(text: config.secretAccessKey);
    pathPrefixController = TextEditingController(text: config.pathPrefix);
    publicBaseUrlController = TextEditingController(text: config.publicBaseUrl);
    usePathStyle = config.usePathStyle;
  }

  @override
  void dispose() {
    endpointController.dispose();
    regionController.dispose();
    bucketController.dispose();
    accessKeyController.dispose();
    secretKeyController.dispose();
    pathPrefixController.dispose();
    publicBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('S3 上传配置'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'https://s3.example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regionController,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  hintText: 'us-east-1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bucketController,
                decoration: const InputDecoration(labelText: 'Bucket'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accessKeyController,
                decoration: const InputDecoration(labelText: 'Access Key ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretKeyController,
                obscureText: obscureSecret,
                decoration: InputDecoration(
                  labelText: 'Secret Access Key',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscureSecret = !obscureSecret),
                    icon: Icon(
                      obscureSecret ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathPrefixController,
                decoration: const InputDecoration(
                  labelText: '上传路径前缀',
                  hintText: 'lingyun-time',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: publicBaseUrlController,
                decoration: const InputDecoration(
                  labelText: '公开访问域名（可选）',
                  hintText: 'https://cdn.example.com/bucket',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: usePathStyle,
                contentPadding: EdgeInsets.zero,
                title: const Text('使用 Path Style'),
                subtitle: const Text('多数 S3 兼容存储使用 endpoint/bucket/object 形式'),
                onChanged: (value) =>
                    setState(() => usePathStyle = value ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              S3UploadConfig(
                endpoint: endpointController.text.trim(),
                region: regionController.text.trim().isEmpty
                    ? 'us-east-1'
                    : regionController.text.trim(),
                bucket: bucketController.text.trim(),
                accessKeyId: accessKeyController.text.trim(),
                secretAccessKey: secretKeyController.text.trim(),
                pathPrefix: pathPrefixController.text.trim(),
                publicBaseUrl: publicBaseUrlController.text.trim(),
                usePathStyle: usePathStyle,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
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
          Text(
            '工具与备份',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text('把导入导出、存储配置统一收进设置页，主页面只负责记录与浏览。'),
        ],
      ),
    );
  }
}
