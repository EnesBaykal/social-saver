/// Uygulama genelinde kullanılan sabitler
class AppConstants {
  AppConstants._();

  /// Backend sunucu adresi — ayarlar ekranından değiştirilebilir
  static String baseUrl = 'http://localhost:8000';

  /// Desteklenen platform domain'leri
  static const List<String> supportedDomains = [
    'youtube.com',
    'youtu.be',
    'tiktok.com',
    'instagram.com',
    'twitter.com',
    'x.com',
  ];

  /// URL'nin desteklenen bir platformdan olup olmadığını kontrol et
  static bool isValidUrl(String url) {
    final lower = url.toLowerCase();
    return supportedDomains.any((domain) => lower.contains(domain));
  }

  /// URL'den platform adını tespit et
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

  /// Platform için Türkçe görüntü adı
  static String platformDisplayName(String platform) {
    const names = {
      'youtube': 'YouTube',
      'tiktok': 'TikTok',
      'instagram': 'Instagram',
      'twitter': 'Twitter/X',
    };
    return names[platform] ?? platform;
  }

  /// Süreyi mm:ss formatına çevir
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Byte boyutunu okunabilir formata çevir
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
