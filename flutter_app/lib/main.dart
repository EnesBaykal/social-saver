import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/api_client.dart';
import 'core/constants.dart';

/// Backend sunucusunu arka planda başlatır (sadece Windows masaüstü)
Future<void> _ensureBackendRunning() async {
  if (!Platform.isWindows) return;

  // Önce sunucu zaten çalışıyor mu kontrol et
  try {
    final socket = await Socket.connect('localhost', 8000,
        timeout: const Duration(seconds: 2));
    socket.destroy();
    return; // Zaten çalışıyor
  } catch (_) {
    // Çalışmıyor, başlat
  }

  // baslat.py'nin konumunu bul (exe yanında veya proje kökünde)
  final candidates = [
    // Geliştirme ortamı: flutter_app/../baslat.py
    '${Directory.current.path}/../baslat.py',
    '${File(Platform.resolvedExecutable).parent.path}/baslat.py',
    r'D:\yazilim\ekipai\sonpreje\baslat.py',
  ];

  String? scriptPath;
  for (final p in candidates) {
    if (await File(p).exists()) {
      scriptPath = p;
      break;
    }
  }

  if (scriptPath == null) return;

  try {
    await Process.start(
      'python',
      [scriptPath],
      workingDirectory: File(scriptPath).parent.path,
      mode: ProcessStartMode.detached,
    );
    // Sunucunun ayağa kalkması için bekle
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final s = await Socket.connect('localhost', 8000,
            timeout: const Duration(seconds: 1));
        s.destroy();
        return;
      } catch (_) {}
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kaydedilmiş sunucu adresini yükle
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('server_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    AppConstants.baseUrl = savedUrl;
  }

  // API istemcisini başlat
  ApiClient.instance.init();

  // Backend'i otomatik başlat (masaüstü)
  await _ensureBackendRunning();

  runApp(
    const ProviderScope(
      child: SocialSaverApp(),
    ),
  );
}

class SocialSaverApp extends StatelessWidget {
  const SocialSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SocialSaver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // Varsayılan dark mod
      routerConfig: appRouter,
    );
  }
}
