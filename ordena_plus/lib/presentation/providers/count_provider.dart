import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordena_plus/presentation/providers/dependency_injection.dart';

final unorganizedCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return await repository.getUnorganizedCount();
});
