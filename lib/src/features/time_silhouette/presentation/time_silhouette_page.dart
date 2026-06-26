import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/memory_item.dart';
import '../data/s3_storage_service.dart';
import 'time_silhouette_controller.dart';

class TimeSilhouettePage extends ConsumerWidget {
  const TimeSilhouettePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timeSilhouetteControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('婴儿时光剪影')),
      body: state.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _HeaderCard(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _ModeChip(label: '照片', icon: Icons.photo),
                _ModeChip(label: '视频', icon: Icons.videocam),
                _ModeChip(label: '按月分组', icon: Icons.calendar_month),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _pickAndUpload(context, ref, 'photo'),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('添加照片'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _pickAndUpload(context, ref, 'video'),
              icon: const Icon(Icons.movie_creation),
              label: const Text('添加视频'),
            ),
            const SizedBox(height: 16),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemoryTile(item: e),
                )),
          ],
        ),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref, String kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: kind == 'photo' ? FileType.image : FileType.video,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    final remoteUrl = await MockS3StorageService().uploadFile(
      localPath: file.path!,
      objectKey: '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
      mimeType: kind == 'photo' ? 'image/*' : 'video/*',
    );
    await ref.read(timeSilhouetteControllerProvider.notifier).addMemory(
          kind: kind,
          localPath: file.path!,
          remoteUrl: remoteUrl,
          createdAt: DateTime.now(),
        );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182131) : const Color(0xFFF2E8DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27364A) : const Color(0xFFE4D3C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时光剪影',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持照片、视频、S3 链接与按月分组的本地保存。',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(item.kind == 'photo' ? Icons.photo : Icons.play_circle),
        title: Text('${item.kind == 'photo' ? '照片' : '视频'} · ${item.groupKey}'),
        subtitle: Text(item.remoteUrl),
      ),
    );
  }
}
