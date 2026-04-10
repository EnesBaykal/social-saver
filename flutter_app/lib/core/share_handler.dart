import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'constants.dart';

/// Diğer uygulamalardan URL paylaşımını dinler (ör: TikTok'tan "Paylaş" butonu)
class ShareHandler {
  StreamSubscription? _streamSub;
  final void Function(String url) _onUrlReceived;

  ShareHandler({required void Function(String url) onUrlReceived})
      : _onUrlReceived = onUrlReceived;

  /// Dinleyiciyi başlat
  void initSharingListener() {
    // Uygulama açıkken gelen paylaşımlar
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

    // Uygulama kapalıyken gelen paylaşımlar (initial)
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
