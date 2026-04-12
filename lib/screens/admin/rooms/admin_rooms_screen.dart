import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../models/models.dart';
import 'package:uuid/uuid.dart';

class AdminRoomsScreen extends ConsumerStatefulWidget {
  const AdminRoomsScreen({super.key});

  @override
  ConsumerState<AdminRoomsScreen> createState() =>
      _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends ConsumerState<AdminRoomsScreen> {
  void _showAddRoomDialog() {
    final nameController = TextEditingController();
    final floorController = TextEditingController(text: '1');
    final capacityController = TextEditingController(text: '30');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. Room 101',
                  prefixIcon: Icon(Icons.meeting_room_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: floorController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                  hintText: 'e.g. 1',
                  prefixIcon: Icon(Icons.layers_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  hintText: 'e.g. 30',
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
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final room = RoomModel(
                          id: const Uuid().v4(),
                          name: nameController.text.trim(),
                          floor: int.tryParse(floorController.text) ?? 1,
                          capacity: int.tryParse(capacityController.text) ?? 30,
                          comfortScore: 100,
                        );
                        await ref
                            .read(firestoreServiceProvider)
                            .addRoom(room);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Room added successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
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
      builder: (ctx) => AlertDialog(
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
              await ref
                  .read(firestoreServiceProvider)
                  .deleteRoom(room.id);
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
        onPressed: _showAddRoomDialog,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded, color: AppColors.primary),
      ),
      body: rooms.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'No Rooms',
                message: 'Tap + to add a room',
                icon: Icons.meeting_room_outlined,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final room = list[index];
                  final color = room.comfortScore >= 70
                      ? AppColors.success
                      : room.comfortScore >= 40
                          ? AppColors.warning
                          : AppColors.error;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
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
                          child: Icon(
                            Icons.meeting_room_rounded,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: AppTypography.labelLarge.copyWith(
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                ),
                              ),
                              Text(
                                'Floor ${room.floor} • Capacity ${room.capacity}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${room.comfortScore.toInt()}%',
                          style: AppTypography.labelLarge
                              .copyWith(color: color),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteDialog(room),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}