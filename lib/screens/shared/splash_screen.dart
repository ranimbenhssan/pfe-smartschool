import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../navigation/app_routes.dart';
import '../../models/models.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CONNECTIVITY CHECK
  //  Tries to resolve a known host — if it fails, no internet.
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NAVIGATE — checks internet first, retries until connected
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // Check connectivity
    final connected = await _hasInternet();
    if (!connected) {
      _showNoConnectionDialog();
      return;
    }

    // Proceed with auth check
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;

      if (user == null) {
        if (mounted) context.go(AppRoutes.login);
        return;
      }

      final currentUser = await ref.read(currentUserProvider.future);
      if (!mounted) return;

      if (currentUser == null) {
        context.go(AppRoutes.login);
        return;
      }

      if (currentUser.firstLogin) {
        context.go(AppRoutes.changePassword);
        return;
      }

      switch (currentUser.role) {
        case UserRole.admin:
          context.go(AppRoutes.adminDashboard);
          break;
        case UserRole.teacher:
          context.go(AppRoutes.teacherDashboard);
          break;
        case UserRole.student:
          context.go(AppRoutes.studentDashboard);
          break;
        default:
          context.go(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('Splash navigate error: $e');
      if (mounted) context.go(AppRoutes.login);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NO CONNECTION DIALOG
  //  Blocks navigation — user must tap "Try Again" to retry.
  // ─────────────────────────────────────────────────────────────────────────
  void _showNoConnectionDialog() {
    if (!mounted || _showingDialog) return;
    _showingDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false, // user cannot dismiss by tapping outside
      builder:
          (ctx) => PopScope(
            canPop: false, // back button also blocked
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 48,
              ),
              title: const Text(
                'No Internet Connection',
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'Faccna requires an internet connection to work.\n\n'
                'Please check your WiFi or mobile data and try again.',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    _showingDialog = false;

                    // Re-check connectivity
                    final connected = await _hasInternet();
                    if (!mounted) return;

                    if (connected) {
                      // Connected — proceed with navigation
                      _navigate();
                    } else {
                      // Still offline — show dialog again
                      _showNoConnectionDialog();
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ─────────────────────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Faccna',
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 255, 212, 103),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart. Connected. Efficient.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8FA3C0),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
