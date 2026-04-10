import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/video_info.dart';
import '../providers/download_provider.dart';

/// Dosyayı platforma uygun konuma kaydeder.
/// Windows: Kullanıcı/Downloads klasörü
/// Android/iOS: Galeri
Future<Map<String, dynamic>> _saveFile(
    String fileUrl, String filename) async {
  final dio = Dio();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Masaüstü: Downloads klasörüne kaydet
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        (await getTemporaryDirectory()).path;
    final downloadsDir = Directory('$home/Downloads/SocialSaver');
    if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);

    final localName = filename.split('/').last;
    final savePath = '${downloadsDir.path}/$localName';

    await dio.download(fileUrl, savePath);
    return {'isSuccess': true, 'filePath': savePath};
  } else {
    // Mobil: galeriye kaydet
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/${filename.split('/').last}';
    await dio.download(fileUrl, localPath);
    final result = await ImageGallerySaver.saveFile(localPath);
    final tmpFile = File(localPath);
    if (await tmpFile.exists()) await tmpFile.delete();
    return result as Map<String, dynamic>;
  }
}

class DownloadScreen extends ConsumerStatefulWidget {
  final VideoInfo videoInfo;

  const DownloadScreen({super.key, required this.videoInfo});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();

    // İlk format varsayılan olarak seç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.videoInfo.formats.isNotEmpty) {
        ref.read(selectedFormatProvider.notifier).state =
            widget.videoInfo.formats.first;
      }
    });
  }

  void _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );
  }

  Future<void> _showCompletionNotification(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'İndirmeler',
      channelDescription: 'Video indirme bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      0,
      'Download Complete',
      title,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// İndirilen dosyayı backend'den al ve uygun konuma kaydet
  Future<void> _saveToGallery(String filename) async {
    final fileUrl = ApiClient.instance.fileUrl(filename);

    try {
      final result = await _saveFile(fileUrl, filename);
      final success = result['isSuccess'] == true;

      if (mounted) {
        final isDesktop =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;
        final msg = success
            ? (isDesktop
                ? 'Saved to Downloads/SocialSaver!'
                : 'Saved to gallery!')
            : 'Save failed. Check permissions.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_outline,
                  color: success ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppColors.cardDark,
          ),
        );
      }
      if (success) await _showCompletionNotification(widget.videoInfo.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: AppColors.cardDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFormat = ref.watch(selectedFormatProvider);
    final downloadState = ref.watch(downloadProvider);

    // İndirme tamamlandıysa galeriye kaydet
    ref.listen<DownloadNotifierState>(downloadProvider, (prev, next) {
      if (next.state == DownloadState.done && next.filename != null) {
        _saveToGallery(next.filename!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            ref.read(downloadProvider.notifier).reset();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video önizleme kartı
            _VideoPreviewCard(videoInfo: widget.videoInfo),

            const SizedBox(height: 24),

            // Format seçici
            if (downloadState.state == DownloadState.idle) ...[
              Text(
                'Select Format',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _FormatSelector(
                formats: widget.videoInfo.formats,
                selected: selectedFormat,
                onSelect: (fmt) =>
                    ref.read(selectedFormatProvider.notifier).state = fmt,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: selectedFormat == null
                    ? null
                    : () => ref
                        .read(downloadProvider.notifier)
                        .startDownload(widget.videoInfo, selectedFormat),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              ),
            ],

            // İndirme ilerlemesi
            if (downloadState.state == DownloadState.starting ||
                downloadState.state == DownloadState.downloading) ...[
              _ProgressWidget(progress: downloadState.progress),
            ],

            // Tamamlandı
            if (downloadState.state == DownloadState.done) ...[
              _DoneWidget(
                onDownloadAgain: () =>
                    ref.read(downloadProvider.notifier).reset(),
              ),
            ],

            // Hata
            if (downloadState.state == DownloadState.error) ...[
              _ErrorWidget(
                message: downloadState.errorMessage ?? 'Bilinmeyen hata',
                onRetry: () => ref.read(downloadProvider.notifier).reset(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Video thumbnail ve bilgi kartı
class _VideoPreviewCard extends StatelessWidget {
  final VideoInfo videoInfo;

  const _VideoPreviewCard({required this.videoInfo});

  Color get _platformColor {
    switch (videoInfo.platform) {
      case 'youtube': return AppColors.youtube;
      case 'tiktok': return const Color(0xFFFF0050);
      case 'instagram': return AppColors.instagram;
      case 'facebook': return AppColors.facebook;
      case 'twitter': return AppColors.twitter;
      default: return AppColors.primary;
    }
  }

  String get _platformName {
    const names = {
      'youtube': 'YouTube', 'tiktok': 'TikTok',
      'instagram': 'Instagram',
      'twitter': 'Twitter/X',
    };
    return names[videoInfo.platform] ?? videoInfo.platform;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: videoInfo.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: videoInfo.thumbnail,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.surfaceDark,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceDark,
                            child: const Icon(Icons.video_library,
                                size: 48, color: AppColors.textSecondary),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceDark,
                          child: const Icon(Icons.video_library,
                              size: 48, color: AppColors.textSecondary),
                        ),
                ),
              ),
              // Platform badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _platformColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _platformName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Başlık ve süre
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoInfo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (videoInfo.duration > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        videoInfo.formattedDuration,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Format seçici listesi
class _FormatSelector extends StatelessWidget {
  final List<VideoFormat> formats;
  final VideoFormat? selected;
  final void Function(VideoFormat) onSelect;

  const _FormatSelector({
    required this.formats,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: formats.map((fmt) {
        final isSelected = selected?.formatId == fmt.formatId;
        final isAudio = fmt.resolution == 'audio';

        return GestureDetector(
          onTap: () => onSelect(fmt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAudio ? Icons.music_note_rounded : Icons.videocam_rounded,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fmt.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// İndirme ilerleme widget'ı
class _ProgressWidget extends StatelessWidget {
  final double progress;

  const _ProgressWidget({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Downloading...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '%${progress.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 10,
              backgroundColor: AppColors.surfaceDark,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tamamlandı widget'ı
class _DoneWidget extends StatelessWidget {
  final VoidCallback onDownloadAgain;

  const _DoneWidget({required this.onDownloadAgain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 52),
          const SizedBox(height: 12),
          const Text(
            'Download Complete!',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'File saved successfully.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onDownloadAgain,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('Download Another Format'),
          ),
        ],
      ),
    );
  }
}

/// Hata widget'ı
class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_rounded, color: AppColors.error, size: 42),
          const SizedBox(height: 10),
          const Text(
            'Download Failed',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
