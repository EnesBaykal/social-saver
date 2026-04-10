import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/video_info.dart';
import '../screens/home_screen.dart';
import '../screens/download_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';

/// App navigation configuration
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/download',
      name: 'download',
      builder: (context, state) {
        final videoInfo = state.extra as VideoInfo;
        return DownloadScreen(videoInfo: videoInfo);
      },
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
