import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/download_task.dart';

/// Download history provider
final historyProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  return ApiClient.instance.getHistory();
});

/// Home screen URL loading state
class HomeNotifierState {
  final bool isLoading;
  final String? errorMessage;

  const HomeNotifierState({
    this.isLoading = false,
    this.errorMessage,
  });

  HomeNotifierState copyWith({bool? isLoading, String? errorMessage}) =>
      HomeNotifierState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class HomeNotifier extends StateNotifier<HomeNotifierState> {
  HomeNotifier() : super(const HomeNotifierState());

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value, errorMessage: null);
  }

  void setError(String message) {
    state = HomeNotifierState(isLoading: false, errorMessage: message);
  }

  void clearError() {
    state = const HomeNotifierState(isLoading: false);
  }
}

final homeProvider =
    StateNotifierProvider.autoDispose<HomeNotifier, HomeNotifierState>(
  (ref) => HomeNotifier(),
);
