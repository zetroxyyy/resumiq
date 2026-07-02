import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/cv/screens/input_screen.dart';
import '../features/cv/screens/generating_screen.dart';
import '../features/cv/screens/template_selection_screen.dart';
import '../features/cv/screens/preview_screen.dart';
import '../features/cv/screens/cv_editor_screen.dart';
import '../features/cv/screens/cover_letter_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/payment/screens/upgrade_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/admin/screens/admin_user_detail_screen.dart';

// Listenable class to notify GoRouter when Auth state changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);
  
  // Watch auth state to execute synchronous redirect logic when building routes
  final authUser = ref.watch(authProvider);
  final authStateAsync = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      // If auth state is loading or has error, don't redirect yet
      if (authStateAsync.isLoading) {
        return '/';
      }

      final isLoggedIn = authUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isSplashing = state.matchedLocation == '/';

      // 1. Not logged in
      if (!isLoggedIn) {
        if (!isLoggingIn && !isSplashing) {
          return '/login';
        }
        return null;
      }

      // 2. Logged in
      if (isLoggedIn) {
        final isFirstTime = authUser.isFirstTime;

        if (isLoggingIn || isSplashing) {
          return isFirstTime ? '/onboarding' : '/home';
        }

        if (isFirstTime && !isOnboarding) {
          return '/onboarding';
        }

        if (!isFirstTime && isOnboarding) {
          return '/home';
        }

        // Pro Guard
        final isProRoute = state.matchedLocation.startsWith('/cv/cover-letter');
        if (isProRoute && !authUser.isPro) {
          return '/home';
        }

        // Admin Guard
        final isAdminRoute = state.matchedLocation.startsWith('/admin');
        if (isAdminRoute && authUser.email != AppConstants.adminEmail) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/cv/input',
        builder: (context, state) => const InputScreen(),
      ),
      GoRoute(
        path: '/cv/generating',
        builder: (context, state) => const GeneratingScreen(),
      ),
      GoRoute(
        path: '/cv/templates',
        builder: (context, state) {
          final cvId = state.uri.queryParameters['cvId'] ?? '';
          return TemplateSelectionScreen(cvId: cvId);
        },
      ),
      GoRoute(
        path: '/cv/preview/:cvId',
        builder: (context, state) {
          final cvId = state.pathParameters['cvId'] ?? '';
          final template = state.uri.queryParameters['template'];
          return PreviewScreen(cvId: cvId, templateName: template);
        },
      ),
      GoRoute(
        path: '/cv/editor/:cvId',
        builder: (context, state) {
          final cvId = state.pathParameters['cvId'] ?? '';
          return CvEditorScreen(cvId: cvId);
        },
      ),
      GoRoute(
        path: '/cv/cover-letter/:cvId',
        builder: (context, state) {
          final cvId = state.pathParameters['cvId'] ?? '';
          return CoverLetterScreen(cvId: cvId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/upgrade',
        builder: (context, state) => const UpgradeScreen(),
      ),
      GoRoute(
        path: '/payment/:plan',
        builder: (context, state) {
          final plan = state.pathParameters['plan'] ?? 'monthly';
          return PaymentScreen(plan: plan);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/admin/user/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return AdminUserDetailScreen(userId: userId);
        },
      ),
    ],
  );
});
