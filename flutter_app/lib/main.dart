import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/api_client.dart';
import 'core/constants.dart';

/// Starts the backend server in the background (Windows desktop only)
Future<void> _ensureBackendRunning() async {
  if (!Platform.isWindows) return;

  // Check if server is already running
  try {
    final socket = await Socket.connect('localhost', 8000,
        timeout: const Duration(seconds: 2));
    socket.destroy();
    return; // Already running
  } catch (_) {
    // Not running, start it
  }

  // Find server.py (next to exe or in project root)
  final candidates = [
    // Development: flutter_app/../server.py
    '${Directory.current.path}/../server.py',
    '${File(Platform.resolvedExecutable).parent.path}/server.py',
    r'D:\yazilim\ekipai\sonpreje\server.py',
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
    // Wait for server to start
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

  // Load saved server address
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('server_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    AppConstants.baseUrl = savedUrl;
  }

  // Initialize API client
  ApiClient.instance.init();

  // Auto-start backend (desktop)
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
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
