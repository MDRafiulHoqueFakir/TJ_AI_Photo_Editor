import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_studio/presentation/ai_studio_screen.dart';
import '../../features/collage/presentation/collage_screen.dart';
import '../../features/editor/presentation/editor_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/passport/presentation/passport_screen.dart';
import '../../features/subscription/presentation/paywall_screen.dart';
import '../../features/tools/presentation/quick_tools_screen.dart';

abstract class Routes {
  static const onboarding = '/';
  static const home = '/home';
  static const editor = '/editor';
  static const aiStudio = '/ai-studio';
  static const quickTools = '/tools';
  static const passport = '/passport';
  static const collage = '/collage';
  static const paywall = '/paywall';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.onboarding,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.editor,
        builder: (_, state) => EditorScreen(imagePath: state.extra as String?),
      ),
      GoRoute(
        path: Routes.aiStudio,
        builder: (_, __) => const AiStudioScreen(),
      ),
      GoRoute(
        path: Routes.quickTools,
        builder: (_, __) => const QuickToolsScreen(),
      ),
      GoRoute(
        path: Routes.passport,
        builder: (_, __) => const PassportScreen(),
      ),
      GoRoute(
        path: Routes.collage,
        builder: (_, __) => const CollageScreen(),
      ),
      GoRoute(
        path: Routes.paywall,
        builder: (_, __) => const PaywallScreen(),
      ),
    ],
  );
});
