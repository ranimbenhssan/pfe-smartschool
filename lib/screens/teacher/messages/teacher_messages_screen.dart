import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../navigation/app_routes.dart';

class TeachermessageScreen extends ConsumerStatefulWidget {
  const TeachermessageScreen({super.key});

  @override
  ConsumerState<TeachermessageScreen> createState() =>
      _TeachermessageScreenState();
}

class _TeachermessageScreenState extends ConsumerState<TeachermessageScreen> {
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
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push(AppRoutes.teachermessageend),
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
              message: 'Please log in',
              icon: Icons.message_rounded,
            );
          }

          final messages = ref.watch(notificationsProvider(user.id));

          return messages.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (list) {
              final filtered =
                  _query.isEmpty
                      ? list
                      : list.where((m) {
                        final q = _query.toLowerCase();
                        return m.title.toLowerCase().contains(q) ||
                            m.message.toLowerCase().contains(q) ||
                            m.senderName.toLowerCase().contains(q);
                      }).toList();

              return Column(
                children: [
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
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                                : null,
                        filled: true,
                        fillColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
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

                  if (_query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 16,
                        bottom: 4,
                      ),
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

                  Expanded(
                    child:
                        filtered.isEmpty
                            ? EmptyState(
                              title:
                                  _query.isEmpty ? 'No messages' : 'No results',
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
                                  message: message,
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
        },
      ),
    );
  }
}
