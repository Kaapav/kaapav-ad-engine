import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;
  final int? filterCount;

  const GlassSearch({super.key, this.hint = 'Search...', this.onChanged, this.onFilter, this.filterCount});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: Glass.blurLight,
        child: Container(
          height: 46,
          decoration: Glass.card(radius: 16),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search_rounded, color: C.textMuted, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: onChanged,
                  style: const TextStyle(color: C.textPrimary, fontSize: 14),
                  cursorColor: C.primary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: C.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              if (onFilter != null) ...[
                Container(width: 1, height: 24, color: C.glassBorder),
                GestureDetector(
                  onTap: onFilter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.tune_rounded, color: filterCount != null && filterCount! > 0 ? C.primary : C.textSecondary, size: 20),
                        if (filterCount != null && filterCount! > 0)
                          Positioned(
                            right: -6, top: -4,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(gradient: C.primaryGrad, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('$filterCount', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const FilterChip2({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? C.primary.withValues(alpha: 0.15) : C.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.primary.withValues(alpha: 0.5) : C.glassBorder),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? C.primary : C.textPrimary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}