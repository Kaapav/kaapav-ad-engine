import 'package:flutter_riverpod/flutter_riverpod.dart';

final sidebarExpandedProvider = StateProvider<bool>((ref) => true);
final activeModalProvider = StateProvider<String?>((ref) => null);
final dateRangeProvider = StateProvider<String>((ref) => 'last_7d');
final searchQueryProvider = StateProvider<String>((ref) => '');
final globalLoadingProvider = StateProvider<bool>((ref) => false);
