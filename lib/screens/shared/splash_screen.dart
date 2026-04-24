import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../navigation/app_routes.dart';
import '../../models/models.dart';    // ← ADD THIS
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

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;

      if (user == null) {
        if (mounted) context.go(AppRoutes.login);
        return;
      }

      // ─── Check first_login ───
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
                // ─── Logo ───
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
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.school_rounded,
                              color: AppColors.accent,
                              size: 60,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SmartSchool',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTypography.displayFont,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart School Management',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent.withValues(alpha: 0.7),
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
