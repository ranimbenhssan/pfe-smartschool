import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminmessageScreen extends ConsumerWidget {
  const AdminmessageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: () => context.push(AppRoutes.adminmessageend),
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
              message: 'Please log in to view messages',
              icon: Icons.message_rounded,
            );
          }
          return _MessageList(userId: user.id);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.adminmessageend),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.send_rounded, color: AppColors.primary),
      ),
    );
  }
}

// ─── Stateful list with search ─────────────────────────────────────────────
class _MessageList extends ConsumerStatefulWidget {
  final String userId;
  const _MessageList({required this.userId});

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = ref.watch(notificationsProvider(widget.userId));

    return messages.when(
      loading: () => const LoadingWidget(),
      error:
          (e, _) => EmptyState(
            title: 'Error',
            message: e.toString(),
            icon: Icons.error_outline_rounded,
          ),
      data: (list) {
        final role =
            ref.watch(currentUserProvider).value?.role ?? UserRole.unknown;
        const systemTypes = {'attendance', 'password_reset'};
        final filteredByRole =
            role == UserRole.superAdmin
                ? list.where((n) {
                  final t = n.rawMessageType;
                  if (systemTypes.contains(t)) return false;
                  if (t == 'absence_flag') {
                    return n.recipientLabel == 'Admin';
                  }
                  return true;
                }).toList()
                : list;
        final filtered =
            _query.isEmpty
                ? filteredByRole
                : filteredByRole.where((m) {
                  final q = _query.toLowerCase();
                  return m.title.toLowerCase().contains(q) ||
                      m.message.toLowerCase().contains(q) ||
                      m.senderName.toLowerCase().contains(q);
                }).toList();

        return Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by subject or sender...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon:
                      _query.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // ── Result count ────────────────────────────────────────────
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 16, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_query"',
                      style: AppTypography.caption.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // ── List ────────────────────────────────────────────────────
            Expanded(
              child:
                  filtered.isEmpty
                      ? EmptyState(
                        title: _query.isEmpty ? 'No messages' : 'No results',
                        message:
                            _query.isEmpty
                                ? 'No messages yet'
                                : 'No messages match "$_query"',
                        icon:
                            _query.isEmpty
                                ? Icons.message_rounded
                                : Icons.search_off_rounded,
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final message = filtered[index];
                          return MessagesTile(
                            message: list[index],
                            showRecipient: true,
                            onTap: () async {
                              await ref
                                  .read(firestoreServiceProvider)
                                  .markNotificationRead(message.id);
                              if (context.mounted) {
                                context.push(
                                  AppRoutes.messageDetail,
                                  extra: message,
                                );
                              }
                            },
                          );
                        },
                      ),
            ),
          ],
        );
      },
    );
  }
}
