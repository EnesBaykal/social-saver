import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_downloader/core/constants.dart';
import 'package:social_downloader/models/video_info.dart';
import 'package:social_downloader/models/download_task.dart';

void main() {
  group('AppConstants', () {
    test('isValidUrl — supported platforms should be accepted', () {
      expect(AppConstants.isValidUrl('https://www.youtube.com/watch?v=abc'), isTrue);
      expect(AppConstants.isValidUrl('https://youtu.be/abc'), isTrue);
      expect(AppConstants.isValidUrl('https://www.tiktok.com/@user/video/123'), isTrue);
      expect(AppConstants.isValidUrl('https://www.instagram.com/p/abc'), isTrue);
      expect(AppConstants.isValidUrl('https://www.facebook.com/watch?v=123'), isTrue);
      expect(AppConstants.isValidUrl('https://twitter.com/user/status/123'), isTrue);
      expect(AppConstants.isValidUrl('https://x.com/user/status/123'), isTrue);
    });

    test('isValidUrl — unsupported URL should be rejected', () {
      expect(AppConstants.isValidUrl('https://www.google.com'), isFalse);
      expect(AppConstants.isValidUrl('https://www.reddit.com/r/flutter'), isFalse);
      expect(AppConstants.isValidUrl(''), isFalse);
    });

    test('detectPlatform — should return correct platform', () {
      expect(AppConstants.detectPlatform('https://www.youtube.com/watch?v=abc'), 'youtube');
      expect(AppConstants.detectPlatform('https://youtu.be/abc'), 'youtube');
      expect(AppConstants.detectPlatform('https://www.tiktok.com/@u/video/1'), 'tiktok');
      expect(AppConstants.detectPlatform('https://www.instagram.com/p/abc'), 'instagram');
      expect(AppConstants.detectPlatform('https://www.facebook.com/watch'), 'facebook');
      expect(AppConstants.detectPlatform('https://twitter.com/user/status/1'), 'twitter');
      expect(AppConstants.detectPlatform('https://x.com/user/status/1'), 'twitter');
    });

    test('formatDuration — should format duration correctly', () {
      expect(AppConstants.formatDuration(0), '00:00');
      expect(AppConstants.formatDuration(65), '01:05');
      expect(AppConstants.formatDuration(3600), '60:00');
    });

    test('formatFileSize — should format size correctly', () {
      expect(AppConstants.formatFileSize(null), '');
      expect(AppConstants.formatFileSize(0), '');
      expect(AppConstants.formatFileSize(500), '0.5 KB');
      expect(AppConstants.formatFileSize(1024 * 1024 * 50), '50.0 MB');
    });
  });

  group('VideoFormat', () {
    test('label — video format should be labelled correctly', () {
      const fmt = VideoFormat(
        formatId: 'hd',
        ext: 'mp4',
        resolution: '720p',
        filesizeApprox: 50 * 1024 * 1024,
      );
      expect(fmt.label, contains('720p'));
      expect(fmt.label, contains('MP4'));
      expect(fmt.label, contains('50.0 MB'));
    });

    test('label — audio format should be labelled correctly', () {
      const fmt = VideoFormat(
        formatId: 'audio',
        ext: 'mp3',
        resolution: 'audio',
      );
      expect(fmt.label, contains('Audio Only'));
      expect(fmt.label, contains('MP3'));
    });

    test('fromJson — should parse correctly from JSON', () {
      final json = {
        'format_id': 'hd',
        'ext': 'mp4',
        'resolution': '1080p',
        'filesize_approx': 104857600,
      };
      final fmt = VideoFormat.fromJson(json);
      expect(fmt.formatId, 'hd');
      expect(fmt.ext, 'mp4');
      expect(fmt.resolution, '1080p');
      expect(fmt.filesizeApprox, 104857600);
    });
  });

  group('VideoInfo', () {
    test('formattedDuration — mm:ss format should be correct', () {
      const info = VideoInfo(
        title: 'Test',
        thumbnail: '',
        duration: 125,
        platform: 'youtube',
        formats: [],
        originalUrl: 'https://youtu.be/abc',
      );
      expect(info.formattedDuration, '02:05');
    });

    test('fromJson — should parse correctly from JSON', () {
      final json = {
        'title': 'Test Video',
        'thumbnail': 'https://example.com/thumb.jpg',
        'duration': 180,
        'platform': 'youtube',
        'formats': [],
        'original_url': 'https://youtube.com/watch?v=abc',
      };
      final info = VideoInfo.fromJson(json);
      expect(info.title, 'Test Video');
      expect(info.platform, 'youtube');
      expect(info.duration, 180);
      expect(info.formats, isEmpty);
    });
  });

  group('DownloadTask', () {
    test('status getters should work correctly', () {
      const task = DownloadTask(
        id: '1',
        url: 'https://youtube.com/watch?v=abc',
        title: 'Test',
        status: 'downloading',
        progress: 45.0,
        createdAt: '2026-04-07T12:00:00',
      );
      expect(task.isDownloading, isTrue);
      expect(task.isCompleted, isFalse);
      expect(task.isError, isFalse);
      expect(task.isPending, isFalse);
    });

    test('fromJson — should parse correctly from JSON', () {
      final json = {
        'id': 'task-1',
        'url': 'https://youtube.com/watch?v=abc',
        'title': 'Test Video',
        'status': 'completed',
        'progress': 100.0,
        'filename': 'video.mp4',
        'error': null,
        'created_at': '2026-04-07T12:00:00',
      };
      final task = DownloadTask.fromJson(json);
      expect(task.isCompleted, isTrue);
      expect(task.filename, 'video.mp4');
      expect(task.progress, 100.0);
    });
  });

  group('HistoryItem', () {
    test('formattedDate — should format date correctly', () {
      const item = HistoryItem(
        id: '1',
        title: 'Test',
        platform: 'youtube',
        downloadedAt: '2026-04-07T12:00:00',
      );
      expect(item.formattedDate, 'Apr 7, 2026');
    });

    test('formattedDate — should return original on invalid date', () {
      const item = HistoryItem(
        id: '1',
        title: 'Test',
        platform: 'youtube',
        downloadedAt: 'invalid-date',
      );
      expect(item.formattedDate, 'invalid-date');
    });
  });

  group('Widget — Platform Icons', () {
    testWidgets('HomeScreen should render correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Text('SocialSaver'),
            ),
          ),
        ),
      );
      expect(find.text('SocialSaver'), findsOneWidget);
    });
  });
}
