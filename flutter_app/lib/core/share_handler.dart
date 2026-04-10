import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'constants.dart';

/// Listens for URL sharing from other apps (e.g. TikTok share button)
class ShareHandler {
  StreamSubscription? _streamSub;
  final void Function(String url) _onUrlReceived;

  ShareHandler({required void Function(String url) onUrlReceived})
      : _onUrlReceived = onUrlReceived;

  /// Start the sharing listener
  void initSharingListener() {
    // Shares received while app is open
    _streamSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        final url = files.first.path.trim();
        if (AppConstants.isValidUrl(url)) {
          _onUrlReceived(url);
        }
      }
    });

    // Shares received while app was closed (initial)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        final url = files.first.path.trim();
        if (AppConstants.isValidUrl(url)) {
          _onUrlReceived(url);
          ReceiveSharingIntent.instance.reset();
        }
      }
    });
  }

  void dispose() {
    _streamSub?.cancel();
  }
}
