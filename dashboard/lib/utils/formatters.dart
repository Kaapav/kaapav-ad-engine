import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Fmt {
  // Currency — ₹12,450
  static String currency(num? value, {int decimals = 0}) {
    if (value == null) return '₹0';
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  // Short currency — ₹12.4K, ₹1.2L, ₹1.5Cr
  static String currencyShort(num? value) {
    if (value == null) return '₹0';
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  // Number — 1,23,456
  static String number(num? value) {
    if (value == null) return '0';
    return NumberFormat('#,##,###', 'en_IN').format(value);
  }

  // Short number — 45.2K, 1.2L
  static String numberShort(num? value) {
    if (value == null) return '0';
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  // Percentage — 3.45%
  static String percent(num? value, {int decimals = 2}) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(decimals)}%';
  }

  // ROAS — 4.20x
  static String roas(num? value) {
    if (value == null) return '0x';
    return '${value.toStringAsFixed(2)}x';
  }

  // ROAS color
  static Color roasColor(num? value) {
    if (value == null) return const Color(0xFF7B7D85);
    if (value >= 4.0) return const Color(0xFF34D399);
    if (value >= 2.5) return const Color(0xFF4ADE80);
    if (value >= 1.5) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  // Date formatting
  static String date(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String dateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  static String timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}