import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const GlassInput({
    super.key, required this.label, this.hint, this.controller, this.keyboardType,
    this.prefixIcon, this.suffix, this.obscure = false, this.maxLines = 1, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: C.textPrimary, fontSize: 14),
          cursorColor: C.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: C.textMuted, fontSize: 14),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: C.textMuted, size: 20) : null,
            suffix: suffix,
            filled: true,
            fillColor: C.glassWhite,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.glassBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.glassBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class GlassDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const GlassDropdown({super.key, required this.label, this.value, required this.items, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: C.glassWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: C.bgCard,
              style: const TextStyle(color: C.textPrimary, fontSize: 14, fontFamily: 'Sora'),
              iconEnabledColor: C.primary,
            ),
          ),
        ),
      ],
    );
  }
}