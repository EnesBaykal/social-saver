/// App-wide constants
class AppConstants {
  AppConstants._();

  /// Backend server address — can be changed from settings
  static String baseUrl = 'http://localhost:8000';

  /// Supported platform domains
  static const List<String> supportedDomains = [
    'youtube.com',
    'youtu.be',
    'tiktok.com',
    'instagram.com',
    'twitter.com',
    'x.com',
  ];

  /// Check if URL is from a supported platform
  static bool isValidUrl(String url) {
    final lower = url.toLowerCase();
    return supportedDomains.any((domain) => lower.contains(domain));
  }

  /// Detect platform name from URL
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'youtube';
    } else if (lower.contains('tiktok.com')) {
      return 'tiktok';
    } else if (lower.contains('instagram.com')) {
      return 'instagram';
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'twitter';
    }
    return 'other';
  }

  /// Display name for platform
  static String platformDisplayName(String platform) {
    const names = {
      'youtube': 'YouTube',
      'tiktok': 'TikTok',
      'instagram': 'Instagram',
      'twitter': 'Twitter/X',
    };
    return names[platform] ?? platform;
  }

  /// Format seconds to mm:ss
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format byte size to human-readable string
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
