import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverController = TextEditingController();
  bool _notificationsEnabled = true;
  String _defaultQuality = 'Best Quality';
  bool _testingConnection = false;
  bool? _connectionResult;
  bool? _cookieExists;
  bool _uploadingCookie = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text =
          prefs.getString('server_url') ?? AppConstants.baseUrl;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _defaultQuality = prefs.getString('default_quality') ?? 'Best Quality';
    });
    await _checkCookieStatus();
  }

  Future<void> _checkCookieStatus() async {
    try {
      final resp = await ApiClient.instance.dio.get('/api/cookies/status');
      if (mounted) {
        setState(() => _cookieExists = resp.data['exists'] as bool);
      }
    } catch (_) {}
  }

  Future<void> _uploadCookieFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      dialogTitle: 'Select cookies.txt file',
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    final path = result.files.first.path;
    if (bytes == null && path == null) return;

    setState(() => _uploadingCookie = true);
    try {
      final data = bytes ?? await File(path!).readAsBytes();
      await ApiClient.instance.dio.post(
        '/api/cookies',
        data: data,
        options: Options(headers: {'Content-Type': 'text/plain'}),
      );
      await _checkCookieStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cookie uploaded! Instagram is ready.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCookie = false);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = _serverController.text.trim();

    await prefs.setString('server_url', url);
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setString('default_quality', _defaultQuality);

    if (url.isNotEmpty) ApiClient.instance.updateBaseUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppColors.cardDark,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });

    final url = _serverController.text.trim();
    ApiClient.instance
        .updateBaseUrl(url.isNotEmpty ? url : AppConstants.baseUrl);

    final result = await ApiClient.instance.testConnection();

    setState(() {
      _testingConnection = false;
      _connectionResult = result;
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Server Settings ──────────────────────────────────────────
            const _SectionTitle('Server Settings'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      hintText: 'http://localhost:8000',
                      labelText: 'Server Address',
                      prefixIcon: Icon(Icons.dns_rounded),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _testingConnection ? null : _testConnection,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      padding: EdgeInsets.zero,
                      backgroundColor: _connectionResult == null
                          ? AppColors.primary
                          : (_connectionResult!
                              ? AppColors.success
                              : AppColors.error),
                    ),
                    child: _testingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            _connectionResult == null
                                ? Icons.wifi_find_rounded
                                : (_connectionResult!
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded),
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
            if (_connectionResult != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _connectionResult! ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: _connectionResult!
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _connectionResult!
                        ? 'Connection successful!'
                        : 'Server unreachable',
                    style: TextStyle(
                      color: _connectionResult!
                          ? AppColors.success
                          : AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Instagram Cookie ─────────────────────────────────────────
            const _SectionTitle('Instagram Cookie'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _cookieExists == true
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          color: _cookieExists == true
                              ? AppColors.success
                              : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _cookieExists == true
                              ? 'Cookie active — Instagram works'
                              : 'No cookie — Instagram won\'t work',
                          style: TextStyle(
                            color: _cookieExists == true
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Install "Get cookies.txt LOCALLY" extension in Edge/Chrome, '
                      'log in to Instagram, export cookies.txt '
                      'and upload it below.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploadingCookie ? null : _uploadCookieFile,
                        icon: _uploadingCookie
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(_uploadingCookie
                            ? 'Uploading...'
                            : 'Upload cookies.txt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Download Settings ─────────────────────────────────────────
            const _SectionTitle('Download Settings'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Quality'),
                        DropdownButton<String>(
                          value: _defaultQuality,
                          dropdownColor: AppColors.cardDark,
                          underline: const SizedBox(),
                          items: const [
                            'Best Quality',
                            '1080p',
                            '720p',
                            '480p',
                            'Audio Only',
                          ]
                              .map((q) => DropdownMenuItem(
                                    value: q,
                                    child: Text(q),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _defaultQuality = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Notify on Download'),
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) =>
                        setState(() => _notificationsEnabled = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),

            const SizedBox(height: 32),

            // ── About ─────────────────────────────────────────────────
            const _SectionTitle('About'),
            const SizedBox(height: 12),
            const Card(
              child: Column(
                children: [
                  _InfoTile('Version', '1.0.0'),
                  Divider(height: 1),
                  _InfoTile('Backend', 'Python FastAPI + yt-dlp'),
                  Divider(height: 1),
                  _InfoTile('Supported Platforms',
                      'YouTube, TikTok, Instagram, Twitter/X'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
