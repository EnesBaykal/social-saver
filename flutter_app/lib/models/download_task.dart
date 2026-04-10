/// Active/completed download task
class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String status;  // pending | downloading | completed | error
  final double progress;
  final String? filename;
  final String? error;
  final String createdAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.status,
    required this.progress,
    this.filename,
    this.error,
    required this.createdAt,
  });

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String,
        url: json['url'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        filename: json['filename'] as String?,
        error: json['error'] as String?,
        createdAt: json['created_at'] as String,
      );

  bool get isPending => status == 'pending';
  bool get isDownloading => status == 'downloading';
  bool get isCompleted => status == 'completed';
  bool get isError => status == 'error';
}

/// History list item
class HistoryItem {
  final String id;
  final String title;
  final String platform;
  final String? filename;
  final String downloadedAt;
  final String? thumbnail;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.platform,
    this.filename,
    required this.downloadedAt,
    this.thumbnail,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        title: json['title'] as String,
        platform: json['platform'] as String,
        filename: json['filename'] as String?,
        downloadedAt: json['downloaded_at'] as String,
        thumbnail: json['thumbnail'] as String?,
      );

  /// Convert date to human-readable format
  String get formattedDate {
    try {
      final dt = DateTime.parse(downloadedAt);
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return downloadedAt;
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}
