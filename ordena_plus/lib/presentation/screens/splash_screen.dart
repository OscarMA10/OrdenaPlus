import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';
import 'package:ordena_plus/presentation/providers/media_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final repository = ref.read(mediaRepositoryProvider);

    // Listen to progress stream
    await for (final progress in repository.syncWithProgress()) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    }

    // After sync is complete, refresh providers
    ref.invalidate(unorganizedMediaProvider);

    // Wait a bit for UI to show 100%
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade600,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ordena+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando archivos... ${(_progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
