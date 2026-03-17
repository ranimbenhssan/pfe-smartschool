import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/services.dart';

// ─── Dashboard Stats (Admin) ───
final dashboardStatsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  return ref.watch(firestoreServiceProvider).getDashboardStats();
});

// ─── Refresh Dashboard ───
final dashboardRefreshProvider = StateProvider<int>((ref) => 0);
