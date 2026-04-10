import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/video_info.dart';
import '../models/download_task.dart';

/// Dio HTTP istemcisi — backend ile iletişim
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  bool _initialized = false;

  /// İstemciyi başlat (sunucu URL'si değiştiğinde yeniden çağrılabilir)
  void init({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Loglama ve hata interceptor'ı
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            throw DioException(
              requestOptions: e.requestOptions,
              error: 'Could not connect to server. Please check the server address.',
              type: e.type,
            );
          }
          if (e.type == DioExceptionType.connectionError) {
            throw DioException(
              requestOptions: e.requestOptions,
              error: 'Connection error. Is the server running?',
              type: e.type,
            );
          }
          handler.next(e);
        },
      ),
    );
    _initialized = true;
  }

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  /// Sunucu URL'sini güncelle
  void updateBaseUrl(String newUrl) {
    init(baseUrl: newUrl);
    AppConstants.baseUrl = newUrl;
  }

  /// Video bilgisini çek
  Future<VideoInfo> getVideoInfo(String url) async {
    try {
      final response = await dio.post('/api/info', data: {'url': url});
      return VideoInfo.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      throw ApiException(msg ?? _dioErrorMessage(e));
    }
  }

  /// İndirme görevini başlat — task_id döner
  Future<String> startDownload(String url, String formatId) async {
    try {
      final response = await dio.post(
        '/api/download',
        data: {'url': url, 'format_id': formatId},
      );
      return response.data['task_id'] as String;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      throw ApiException(msg ?? _dioErrorMessage(e));
    }
  }

  /// İndirme ilerlemesini sorgula
  Future<DownloadTask> getProgress(String taskId) async {
    try {
      final response = await dio.get('/api/progress/$taskId');
      return DownloadTask.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException(_dioErrorMessage(e));
    }
  }

  /// İndirme geçmişini getir
  Future<List<HistoryItem>> getHistory() async {
    try {
      final response = await dio.get('/api/history');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(_dioErrorMessage(e));
    }
  }

  /// Geçmiş öğesini sil
  Future<bool> deleteHistory(String id) async {
    try {
      await dio.delete('/api/history/$id');
      return true;
    } on DioException catch (e) {
      throw ApiException(_dioErrorMessage(e));
    }
  }

  /// Tüm geçmişi temizle
  Future<void> clearHistory() async {
    try {
      await dio.delete('/api/history');
    } on DioException catch (e) {
      throw ApiException(_dioErrorMessage(e));
    }
  }

  /// Bağlantıyı test et
  Future<bool> testConnection() async {
    try {
      final response = await dio.get(
        '/api/history',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dosya indirme URL'si oluştur
  String fileUrl(String filename) {
    return '${AppConstants.baseUrl}/api/files/$filename';
  }

  String _dioErrorMessage(DioException e) {
    if (e.error is String) return e.error as String;
    return 'An error occurred: ${e.message ?? 'Unknown'}';
  }
}

/// API hata sınıfı
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
