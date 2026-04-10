import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/download_task.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear All',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 52, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('Failed to load history',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(historyProvider),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 44),
                ),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyHistoryWidget()
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(historyProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _HistoryTile(item: items[index], ref: ref),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Clear All History'),
        content: const Text('All download history will be deleted. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.instance.clearHistory();
      ref.invalidate(historyProvider);
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final WidgetRef ref;

  const _HistoryTile({required this.item, required this.ref});

  Color get _platformColor {
    switch (item.platform) {
      case 'youtube': return AppColors.youtube;
      case 'tiktok': return const Color(0xFFFF0050);
      case 'instagram': return AppColors.instagram;
      case 'facebook': return AppColors.facebook;
      default: return AppColors.primary;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Remove from History'),
        content: const Text('This item will be removed from history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiClient.instance.deleteHistory(item.id);
        ref.invalidate(historyProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not delete. Check connection.'),
              backgroundColor: AppColors.cardDark,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: (item.thumbnail != null && item.thumbnail!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: item.thumbnail!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceDark,
                      child: const Icon(Icons.video_library,
                          color: AppColors.textSecondary),
                    ),
                  )
                : Container(
                    color: AppColors.surfaceDark,
                    child: const Icon(Icons.video_library,
                        color: AppColors.textSecondary),
                  ),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${item.platform.toUpperCase()} • ${item.formattedDate}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _platformColor,
            shape: BoxShape.circle,
          ),
        ),
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }
}

class _EmptyHistoryWidget extends StatelessWidget {
  const _EmptyHistoryWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'No downloads yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your downloaded videos will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
