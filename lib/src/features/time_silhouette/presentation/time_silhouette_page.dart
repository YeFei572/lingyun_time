import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../shared/models/memory_item.dart';
import '../../../shared/widgets/delete_confirm_dialog.dart';
import '../data/s3_storage_service.dart';
import 's3_config_controller.dart';
import 'time_silhouette_controller.dart';

class TimeSilhouettePage extends ConsumerStatefulWidget {
  const TimeSilhouettePage({super.key});

  @override
  ConsumerState<TimeSilhouettePage> createState() => _TimeSilhouettePageState();
}

class _TimeSilhouettePageState extends ConsumerState<TimeSilhouettePage> {
  var _filter = _MemoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timeSilhouetteControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('时光剪影'),
        actions: [
          IconButton(
            tooltip: '添加照片',
            onPressed: () => _pickAndUpload(context, ref, 'photo'),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          IconButton(
            tooltip: '添加视频',
            onPressed: () => _pickAndUpload(context, ref, 'video'),
            icon: const Icon(Icons.video_call_outlined),
          ),
        ],
      ),
      body: state.when(
        data: (items) => _AlbumTimeline(
          items: _filterItems(items),
          allItems: items,
          filter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          onAddPhoto: () => _pickAndUpload(context, ref, 'photo'),
          onAddVideo: () => _pickAndUpload(context, ref, 'video'),
          onDelete: (item) => _confirmDeleteMemory(context, ref, item),
        ),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    String kind,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: kind == 'photo' ? FileType.image : FileType.video,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;

    final config = await ref.read(s3ConfigControllerProvider.future);
    if (!config.isConfigured) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在设置页完成 S3 上传配置')));
      return;
    }

    final createdAt = DateTime.now();
    final objectKey = _buildObjectKey(
      kind: kind,
      fileName: file.name,
      pathPrefix: config.pathPrefix,
      createdAt: createdAt,
    );
    final mimeType = _resolveMimeType(file.extension, kind);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('正在上传${kind == 'photo' ? '照片' : '视频'}...'),
          ],
        ),
      ),
    );

    try {
      final storageService = S3StorageService(config);
      final remoteUrl = await storageService.uploadFile(
        localPath: file.path!,
        objectKey: objectKey,
        mimeType: mimeType,
      );
      final coverUrl = kind == 'video'
          ? await _generateAndUploadVideoCover(
              storageService: storageService,
              videoPath: file.path!,
              videoFileName: file.name,
              pathPrefix: config.pathPrefix,
              createdAt: createdAt,
            )
          : '';
      await ref
          .read(timeSilhouetteControllerProvider.notifier)
          .addMemory(
            kind: kind,
            localPath: file.path!,
            remoteUrl: remoteUrl,
            createdAt: createdAt,
            coverUrl: coverUrl,
          );
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('上传成功')));
    } catch (error) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('上传失败：$error')));
    }
  }

  Future<String> _generateAndUploadVideoCover({
    required S3StorageService storageService,
    required String videoPath,
    required String videoFileName,
    required String pathPrefix,
    required DateTime createdAt,
  }) async {
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 82,
      );
      if (thumbnailPath == null || thumbnailPath.isEmpty) {
        return '';
      }

      final thumbnailFile = File(thumbnailPath);
      if (!await thumbnailFile.exists()) {
        return '';
      }

      return storageService.uploadFile(
        localPath: thumbnailPath,
        objectKey: _buildObjectKey(
          kind: 'videoCover',
          fileName: _coverFileNameFor(videoFileName),
          pathPrefix: pathPrefix,
          createdAt: createdAt,
        ),
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      return '';
    }
  }

  String _buildObjectKey({
    required String kind,
    required String fileName,
    required String pathPrefix,
    required DateTime createdAt,
  }) {
    final prefix = pathPrefix.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final kindDir = switch (kind) {
      'video' => 'videos',
      'videoCover' => 'video-covers',
      _ => 'photos',
    };
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final datePath = [
      createdAt.year.toString().padLeft(4, '0'),
      createdAt.month.toString().padLeft(2, '0'),
      createdAt.day.toString().padLeft(2, '0'),
    ].join('/');
    final finalName = '${createdAt.millisecondsSinceEpoch}_$safeFileName';
    return [
      if (prefix.isNotEmpty) prefix,
      kindDir,
      datePath,
      finalName,
    ].join('/');
  }

  String _coverFileNameFor(String videoFileName) {
    final safeBaseName = videoFileName
        .replaceFirst(RegExp(r'\.[^.]*$'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${safeBaseName.isEmpty ? 'video' : safeBaseName}.jpg';
  }

  String _resolveMimeType(String? extension, String kind) {
    final ext = (extension ?? '').toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'avi' => 'video/x-msvideo',
      _ => kind == 'photo' ? 'image/jpeg' : 'video/mp4',
    };
  }

  List<MemoryItem> _filterItems(List<MemoryItem> items) {
    final sortedItems = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return switch (_filter) {
      _MemoryFilter.all => sortedItems,
      _MemoryFilter.photo => sortedItems.where((e) => e.isPhoto).toList(),
      _MemoryFilter.video => sortedItems.where((e) => e.isVideo).toList(),
    };
  }

  Future<void> _confirmDeleteMemory(
    BuildContext context,
    WidgetRef ref,
    MemoryItem item,
  ) async {
    final kindText = item.isPhoto ? '照片' : '视频';
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: '删除这条$kindText？',
      message: '删除后本地剪影记录将无法恢复。已上传到 S3 的文件不会自动删除。',
    );

    if (!confirmed) {
      return;
    }
    await ref
        .read(timeSilhouetteControllerProvider.notifier)
        .deleteMemory(item.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$kindText记录已删除')));
  }
}

enum _MemoryFilter { all, photo, video }

class _AlbumTimeline extends StatelessWidget {
  const _AlbumTimeline({
    required this.items,
    required this.allItems,
    required this.filter,
    required this.onFilterChanged,
    required this.onAddPhoto,
    required this.onAddVideo,
    required this.onDelete,
  });

  final List<MemoryItem> items;
  final List<MemoryItem> allItems;
  final _MemoryFilter filter;
  final ValueChanged<_MemoryFilter> onFilterChanged;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;
  final ValueChanged<MemoryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(items);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _AlbumToolbar(
            filter: filter,
            allCount: allItems.length,
            photoCount: allItems.where((e) => e.isPhoto).length,
            videoCount: allItems.where((e) => e.isVideo).length,
            onFilterChanged: onFilterChanged,
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyAlbumHint(
              onAddPhoto: onAddPhoto,
              onAddVideo: onAddVideo,
            ),
          )
        else
          SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _MemoryDaySection(
                group: group,
                visibleItems: items,
                onDelete: onDelete,
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<_MemoryDayGroup> _groupByDay(List<MemoryItem> sourceItems) {
    final groupMap = <DateTime, List<MemoryItem>>{};
    for (final item in sourceItems) {
      final key = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      groupMap.putIfAbsent(key, () => <MemoryItem>[]).add(item);
    }

    return groupMap.entries.map((entry) {
      return _MemoryDayGroup(
        day: entry.key,
        label: _formatDayLabel(entry.key),
        items: entry.value,
      );
    }).toList();
  }

  String _formatDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) {
      return '今天';
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return '昨天';
    }
    return DateFormat('yyyy年M月d日').format(day);
  }
}

class _AlbumToolbar extends StatelessWidget {
  const _AlbumToolbar({
    required this.filter,
    required this.allCount,
    required this.photoCount,
    required this.videoCount,
    required this.onFilterChanged,
  });

  final _MemoryFilter filter;
  final int allCount;
  final int photoCount;
  final int videoCount;
  final ValueChanged<_MemoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$allCount 个项目',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_MemoryFilter>(
              segments: [
                ButtonSegment(
                  value: _MemoryFilter.all,
                  label: Text('全部 $allCount'),
                ),
                ButtonSegment(
                  value: _MemoryFilter.photo,
                  label: Text('照片 $photoCount'),
                ),
                ButtonSegment(
                  value: _MemoryFilter.video,
                  label: Text('视频 $videoCount'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (value) => onFilterChanged(value.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlbumHint extends StatelessWidget {
  const _EmptyAlbumHint({required this.onAddPhoto, required this.onAddVideo});

  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有照片或视频',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('添加照片'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddVideo,
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('添加视频'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryDayGroup {
  const _MemoryDayGroup({
    required this.day,
    required this.label,
    required this.items,
  });

  final DateTime day;
  final String label;
  final List<MemoryItem> items;
}

class _MemoryDaySection extends StatelessWidget {
  const _MemoryDaySection({
    required this.group,
    required this.visibleItems,
    required this.onDelete,
  });

  final _MemoryDayGroup group;
  final List<MemoryItem> visibleItems;
  final ValueChanged<MemoryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${group.items.length}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 116).floor().clamp(
                3,
                6,
              );
              return GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemBuilder: (context, index) {
                  final item = group.items[index];
                  return _MemoryThumbnail(
                    item: item,
                    onLongPress: () => onDelete(item),
                    onTap: () {
                      final initialIndex = visibleItems.indexWhere(
                        (e) => e.id == item.id,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _MemoryPreviewPage(
                            items: visibleItems,
                            initialIndex: initialIndex < 0 ? 0 : initialIndex,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemoryThumbnail extends StatelessWidget {
  const _MemoryThumbnail({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final MemoryItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumbnailUrlFor(item).isNotEmpty)
              CachedNetworkImage(
                imageUrl: _thumbnailUrlFor(item),
                cacheKey: '${item.id}-thumbnail',
                fit: BoxFit.cover,
                placeholder: (context, url) => _ThumbnailFallback(item: item),
                errorWidget: (context, url, error) =>
                    _ThumbnailFallback(item: item),
              )
            else
              _ThumbnailFallback(item: item),
            if (item.isVideo)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _thumbnailUrlFor(MemoryItem item) {
    if (item.isVideo) {
      return item.coverUrl;
    }
    if (item.isPhoto) {
      return item.remoteUrl;
    }
    return '';
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          item.isVideo
              ? Icons.play_circle_outline
              : Icons.image_not_supported_outlined,
          color: scheme.onSurfaceVariant,
          size: 30,
        ),
      ),
    );
  }
}

class _MemoryPreviewPage extends StatefulWidget {
  const _MemoryPreviewPage({required this.items, required this.initialIndex});

  final List<MemoryItem> items;
  final int initialIndex;

  @override
  State<_MemoryPreviewPage> createState() => _MemoryPreviewPageState();
}

class _MemoryPreviewPageState extends State<_MemoryPreviewPage> {
  late final PageController _pageController;
  late int _index;

  MemoryItem get _currentItem => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAround(_index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(DateFormat('yyyy年M月d日 HH:mm').format(item.createdAt)),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (value) {
                setState(() => _index = value);
                _precacheAround(value);
              },
              itemBuilder: (context, index) {
                final pageItem = widget.items[index];
                return _MemoryPreviewBody(
                  item: pageItem,
                  isActive: index == _index,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Icon(
                    item.isPhoto
                        ? Icons.photo_outlined
                        : Icons.play_circle_outline,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.isPhoto ? '照片' : '视频',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_index + 1}/${widget.items.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _precacheAround(int index) {
    for (final targetIndex in [index - 1, index, index + 1]) {
      if (targetIndex < 0 || targetIndex >= widget.items.length) {
        continue;
      }
      final item = widget.items[targetIndex];
      if (!item.isPhoto || item.remoteUrl.isEmpty) {
        continue;
      }
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(item.remoteUrl, cacheKey: item.id),
          context,
        ).catchError((_) {}),
      );
    }
  }
}

class _MemoryPreviewBody extends StatefulWidget {
  const _MemoryPreviewBody({required this.item, required this.isActive});

  final MemoryItem item;
  final bool isActive;

  @override
  State<_MemoryPreviewBody> createState() => _MemoryPreviewBodyState();
}

class _MemoryPreviewBodyState extends State<_MemoryPreviewBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    if (item.isPhoto && item.remoteUrl.isNotEmpty) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: item.remoteUrl,
            cacheKey: item.id,
            fit: BoxFit.contain,
            placeholder: (context, url) {
              return const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
              );
            },
            errorWidget: (context, url, error) {
              return const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 54,
              );
            },
          ),
        ),
      );
    }

    if (item.isVideo && item.remoteUrl.isNotEmpty) {
      return _VideoPreview(item: item, isActive: widget.isActive);
    }

    return _VideoFallback(item: item);
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.item, required this.isActive});

  final MemoryItem item;
  final bool isActive;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  late Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.remoteUrl != widget.item.remoteUrl) {
      _controller
        ..removeListener(_onVideoChanged)
        ..dispose();
      _setupController();
      return;
    }
    if (!widget.isActive && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onVideoChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _VideoError(message: snapshot.error.toString());
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final value = _controller.value;
        if (value.hasError) {
          return _VideoError(message: value.errorDescription ?? '视频加载失败');
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio == 0
                      ? 16 / 9
                      : value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
              if (!value.isPlaying)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              if (value.isBuffering)
                const Positioned(
                  top: 24,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _VideoControls(controller: _controller),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setupController() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.item.remoteUrl),
    )..addListener(_onVideoChanged);
    _initializeFuture = _controller.initialize();
  }

  void _onVideoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePlay() async {
    if (!_controller.value.isInitialized) {
      return;
    }
    if (_controller.value.isPlaying) {
      await _controller.pause();
      return;
    }
    await _controller.play();
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 72),
          const SizedBox(height: 16),
          Text(
            DateFormat('yyyy年M月d日 HH:mm').format(item.createdAt),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 54),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
