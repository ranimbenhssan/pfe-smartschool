import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: () => context.push(AppRoutes.adminNotificationSend),
          ),
          currentUser.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data:
                (user) =>
                    user == null
                        ? const SizedBox.shrink()
                        : IconButton(
                          icon: const Icon(Icons.done_all_rounded),
                          onPressed: () async {
                            await ref
                                .read(firestoreServiceProvider)
                                .markAllNotificationsRead(user.id);
                          },
                        ),
          ),
        ],
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              title: 'Not logged in',
              message: 'Please log in to view notifications',
              icon: Icons.notifications_off_rounded,
            );
          }
          return _NotificationsList(userId: user.id);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminNotificationSend),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.send_rounded, color: AppColors.primary),
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  final String userId;

  const _NotificationsList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider(userId));

    return notifications.when(
      loading: () => const LoadingWidget(),
      error:
          (e, _) => EmptyState(
            title: 'Error',
            message: e.toString(),
            icon: Icons.error_outline_rounded,
          ),
      data:
          (list) =>
              list.isEmpty
                  ? const EmptyState(
                    title: 'No Notifications',
                    message: 'No notifications yet',
                    icon: Icons.notifications_none_rounded,
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final notification = list[index];
                      return NotificationTile(
                        notification: notification,
                        onTap: () async {
                          await ref
                              .read(firestoreServiceProvider)
                              .markNotificationRead(notification.id);
                        },
                      );
                    },
                  ),
    );
  }
}
