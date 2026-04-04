import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lead.dart';
import 'app_providers.dart';

/// Pipeline counts per stage
final pipelineCountsProvider = Provider<Map<String, int>>((ref) {
  final leadsAsync = ref.watch(leadsProvider);
  return leadsAsync.when(
    data: (leads) {
      final counts = <String, int>{};
      for (final lead in leads) {
        counts[lead.stage] = (counts[lead.stage] ?? 0) + 1;
      }
      return counts;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Pipeline total value
final pipelineValueProvider = Provider<double>((ref) {
  final leadsAsync = ref.watch(leadsProvider);
  return leadsAsync.when(
    data: (leads) =>
        leads.fold(0.0, (sum, l) => sum + (l.value ?? 0)),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Leads filtered by stage
final leadsFilterProvider = StateProvider<String>((ref) => 'All');
final leadsSortProvider = StateProvider<String>((ref) => 'updatedAt');

final filteredLeadsProvider = Provider<List<Lead>>((ref) {
  final leadsAsync = ref.watch(leadsProvider);
  final filter = ref.watch(leadsFilterProvider);

  return leadsAsync.when(
    data: (leads) {
      var list = leads.toList();
      if (filter != 'All') {
        list = list.where((l) => l.stage == filter).toList();
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});