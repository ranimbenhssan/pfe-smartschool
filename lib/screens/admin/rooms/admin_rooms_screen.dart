import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class AdminRoomsScreen extends ConsumerStatefulWidget {
  const AdminRoomsScreen({super.key});

  @override
  ConsumerState<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends ConsumerState<AdminRoomsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Rooms'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
      body: rooms.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          // Filter
          final filtered =
              _query.isEmpty
                  ? list
                  : list
                      .where(
                        (r) =>
                            r.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ||
                            r.floor.toString().contains(_query),
                      )
                      .toList();

          return Column(
            children: [
              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search rooms...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
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

              // ── Count ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} room${filtered.length == 1 ? '' : 's'}',
                    style: AppTypography.caption.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ),

              // ── Room list ───────────────────────────────────────────────
              Expanded(
                child:
                    filtered.isEmpty
                        ? EmptyState(
                          title: _query.isEmpty ? 'No Rooms' : 'No Results',
                          message:
                              _query.isEmpty
                                  ? 'Tap + to add a room'
                                  : 'No rooms match "$_query"',
                          icon: Icons.meeting_room_outlined,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder:
                              (ctx, i) => _RoomCard(
                                room: filtered[i],
                                isDark: isDark,
                                onTap:
                                    () => context.push(
                                      '${AppRoutes.adminRoomDetail}/${filtered[i].id}',
                                    ),
                                onDelete: () => _showDeleteDialog(filtered[i]),
                              ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final floorCtrl = TextEditingController(text: '1');
    final capacityCtrl = TextEditingController(text: '30');
    bool loading = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, ss) => AlertDialog(
                  title: const Text('Add Room'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Room Name',
                          hintText: 'e.g. Salle 7',
                          prefixIcon: Icon(Icons.meeting_room_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: floorCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Floor',
                          prefixIcon: Icon(Icons.layers_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: capacityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                          prefixIcon: Icon(Icons.people_rounded),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    loading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            ss(() => loading = true);
                            try {
                              await ref
                                  .read(firestoreServiceProvider)
                                  .addRoom(
                                    RoomModel(
                                      id: const Uuid().v4(),
                                      name: nameCtrl.text.trim(),
                                      floor: int.tryParse(floorCtrl.text) ?? 1,
                                      capacity:
                                          int.tryParse(capacityCtrl.text) ?? 30,
                                      comfortScore: 100,
                                    ),
                                  );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room added')),
                                );
                              }
                            } catch (e) {
                              ss(() => loading = false);
                            }
                          },
                          child: const Text('Add'),
                        ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteDialog(RoomModel room) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Room'),
            content: Text('Delete "${room.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: () async {
                  await ref.read(firestoreServiceProvider).deleteRoom(room.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

// ─────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final bool isDark;
  final VoidCallback onTap, onDelete;

  const _RoomCard({
    required this.room,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        room.comfortScore >= 70
            ? AppColors.success
            : room.comfortScore >= 40
            ? AppColors.warning
            : AppColors.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.meeting_room_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    'Floor ${room.floor} · ${room.capacity} seats',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
