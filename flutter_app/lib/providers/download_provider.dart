import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/video_info.dart';

/// Download screen state
enum DownloadState { idle, starting, downloading, saving, done, error }

class DownloadNotifierState {
  final DownloadState state;
  final double progress;
  final String? taskId;
  final String? filename;
  final String? errorMessage;

  const DownloadNotifierState({
    this.state = DownloadState.idle,
    this.progress = 0,
    this.taskId,
    this.filename,
    this.errorMessage,
  });

  DownloadNotifierState copyWith({
    DownloadState? state,
    double? progress,
    String? taskId,
    String? filename,
    String? errorMessage,
  }) =>
      DownloadNotifierState(
        state: state ?? this.state,
        progress: progress ?? this.progress,
        taskId: taskId ?? this.taskId,
        filename: filename ?? this.filename,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// Selected format state management
final selectedFormatProvider = StateProvider.autoDispose<VideoFormat?>((ref) => null);

/// Download state management
class DownloadNotifier extends StateNotifier<DownloadNotifierState> {
  DownloadNotifier() : super(const DownloadNotifierState());

  Timer? _pollTimer;

  /// Start download
  Future<void> startDownload(VideoInfo videoInfo, VideoFormat format) async {
    state = state.copyWith(state: DownloadState.starting, progress: 0);

    try {
      // Send download request to backend
      final taskId = await ApiClient.instance.startDownload(
        videoInfo.originalUrl,
        format.formatId,
      );

      state = state.copyWith(
        state: DownloadState.downloading,
        taskId: taskId,
        progress: 0,
      );

      // Poll progress every 500ms
      _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _checkProgress(taskId);
      });
    } on ApiException catch (e) {
      state = state.copyWith(
        state: DownloadState.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        state: DownloadState.error,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  Future<void> _checkProgress(String taskId) async {
    try {
      final task = await ApiClient.instance.getProgress(taskId);

      if (task.isDownloading) {
        state = state.copyWith(
          state: DownloadState.downloading,
          progress: task.progress,
        );
      } else if (task.isCompleted) {
        _pollTimer?.cancel();
        state = state.copyWith(
          state: DownloadState.done,
          progress: 100,
          filename: task.filename,
        );
      } else if (task.isError) {
        _pollTimer?.cancel();
        state = state.copyWith(
          state: DownloadState.error,
          errorMessage: task.error ?? 'Download failed',
        );
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  /// Reset state (for new download)
  void reset() {
    _pollTimer?.cancel();
    state = const DownloadNotifierState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final downloadProvider =
    StateNotifierProvider.autoDispose<DownloadNotifier, DownloadNotifierState>(
  (ref) => DownloadNotifier(),
);
