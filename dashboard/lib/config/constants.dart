class AppConstants {
  static const List<DatePreset> datePresets = [
    DatePreset(label: 'Today', value: 'today'),
    DatePreset(label: 'Yesterday', value: 'yesterday'),
    DatePreset(label: 'Last 7 Days', value: 'last_7d'),
    DatePreset(label: 'Last 14 Days', value: 'last_14d'),
    DatePreset(label: 'Last 30 Days', value: 'last_30d'),
    DatePreset(label: 'This Month', value: 'this_month'),
    DatePreset(label: 'Last Month', value: 'last_month'),
  ];
}

class DatePreset {
  final String label;
  final String value;
  const DatePreset({required this.label, required this.value});
}
