import 'package:intl/intl.dart';

class U {
  // FORMAT CURRENCY: 1234 → ₹1,234
  static String money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  // FORMAT NUMBER: 1234567 → 12.3L
  static String num(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  // FORMAT PERCENTAGE
  static String pct(double v) => '${v.toStringAsFixed(1)}%';

  // FORMAT ROAS
  static String roas(double v) => '${v.toStringAsFixed(1)}x';

  // FORMAT DATE
  static String date(DateTime d) => DateFormat('dd MMM').format(d);
  static String dateTime(DateTime d) => DateFormat('dd MMM, HH:mm').format(d);
  static String dateFull(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  // TIME AGO
  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  // CALCULATE ROAS
  static double calcRoas(double revenue, double spend) {
    if (spend == 0) return 0;
    return revenue / spend;
  }

  // CALCULATE CPA
  static double calcCpa(double spend, int conversions) {
    if (conversions == 0) return 0;
    return spend / conversions;
  }
}