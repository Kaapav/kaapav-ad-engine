import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meta_auth.dart';

final metaAuthProvider = Provider<MetaAuth>((ref) => MetaAuth());

final isOnboardedProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(metaAuthProvider);
  return auth.isOnboarded();
});

final hasValidConfigProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(metaAuthProvider);
  return auth.hasValidConfig();
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

final authStatusProvider = StateProvider<AuthStatus>((ref) => AuthStatus.initial);