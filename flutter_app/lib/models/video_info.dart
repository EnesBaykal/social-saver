/// Video format modeli
class VideoFormat {
  final String formatId;
  final String ext;
  final String resolution;
  final int? filesizeApprox;

  const VideoFormat({
    required this.formatId,
    required this.ext,
    required this.resolution,
    this.filesizeApprox,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) => VideoFormat(
        formatId: json['format_id'] as String,
        ext: json['ext'] as String,
        resolution: json['resolution'] as String,
        filesizeApprox: json['filesize_approx'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'format_id': formatId,
        'ext': ext,
        'resolution': resolution,
        'filesize_approx': filesizeApprox,
      };

  /// Okunabilir etiket: "720p • MP4 • ~45 MB"
  String get label {
    final sizePart = filesizeApprox != null && filesizeApprox! > 0
        ? ' • ~${_formatSize(filesizeApprox!)}'
        : '';
    if (resolution == 'audio') return 'Audio Only • MP3$sizePart';
    if (resolution == 'Best Quality') return 'Best Quality • MP4';
    return '$resolution • ${ext.toUpperCase()}$sizePart';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// URL'den çekilen video metadata'sı
class VideoInfo {
  final String title;
  final String thumbnail;
  final int duration;
  final String platform;
  final List<VideoFormat> formats;
  final String originalUrl;

  const VideoInfo({
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.platform,
    required this.formats,
    required this.originalUrl,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        title: json['title'] as String,
        thumbnail: json['thumbnail'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
        platform: json['platform'] as String,
        formats: (json['formats'] as List<dynamic>)
            .map((e) => VideoFormat.fromJson(e as Map<String, dynamic>))
            .toList(),
        originalUrl: json['original_url'] as String,
      );

  /// Süreyi mm:ss formatında döndür
  String get formattedDuration {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
