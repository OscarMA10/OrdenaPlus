import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/screens/splash_screen.dart';
import 'package:ordena_plus/presentation/screens/home_screen.dart';
import 'package:ordena_plus/presentation/screens/folder_gallery_screen.dart';
import 'package:ordena_plus/presentation/screens/albums_screen.dart';
import 'package:ordena_plus/presentation/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

CustomTransitionPage buildPageWithFadeTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => buildPageWithFadeTransition<void>(
        context: context,
        state: state,
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/folder/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.extra as String? ?? 'Carpeta';
        return FolderGalleryScreen(folderId: id, folderName: name);
      },
    ),
    GoRoute(
      path: '/albums',
      pageBuilder: (context, state) => buildPageWithFadeTransition<void>(
        context: context,
        state: state,
        child: const AlbumsScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => buildPageWithFadeTransition<void>(
        context: context,
        state: state,
        child: const SettingsScreen(),
      ),
    ),
  ],
  initialLocation: '/splash',
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Ordena+',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
