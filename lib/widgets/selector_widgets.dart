import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SelectorSection extends StatelessWidget {
  final bool isDark;
  final String title;
  final Widget child;

  const SelectorSection({
    super.key,
    required this.isDark,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }
}

class SelectTile extends StatelessWidget {
  final bool isDark;
  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const SelectTile({
    super.key,
    required this.isDark,
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? activeColor.withValues(alpha: 0.08)
                  : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? activeColor.withValues(alpha: 0.4)
                    : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: isSelected ? activeColor : null,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SEARCHABLE SELECTOR
//  Drop-in list with built-in search bar
// ─────────────────────────────────────────
class SearchableSelector<T> extends StatefulWidget {
  final bool isDark;
  final String title;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final String Function(T) idOf;
  final List<String> selectedIds;
  final Function(T item, bool isSelected) onToggle;
  final Color? activeColor;

  const SearchableSelector({
    super.key,
    required this.isDark,
    required this.title,
    required this.hint,
    required this.items,
    required this.labelOf,
    this.subtitleOf,
    required this.idOf,
    required this.selectedIds,
    required this.onToggle,
    this.activeColor,
  });

  @override
  State<SearchableSelector<T>> createState() => _SearchableSelectorState<T>();
}

class _SearchableSelectorState<T> extends State<SearchableSelector<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ─── Filter items by query ───
    final filtered =
        _query.isEmpty
            ? widget.items
            : widget.items.where((item) {
              final label = widget.labelOf(item).toLowerCase();
              final subtitle =
                  widget.subtitleOf?.call(item).toLowerCase() ?? '';
              return label.contains(_query) || subtitle.contains(_query);
            }).toList();

    final selectedCount = widget.selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header row ───
        Row(
          children: [
            Text(widget.title, style: AppTypography.labelMedium),
            const Spacer(),
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.activeColor ?? AppColors.accent).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$selectedCount selected',
                  style: AppTypography.caption.copyWith(
                    color: widget.activeColor ?? AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // ─── Search bar ───
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.caption,
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon:
                _query.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                    : null,
            filled: true,
            fillColor: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color:
                    widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color:
                    widget.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.activeColor ?? AppColors.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ─── Results count ───
        if (_query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              filtered.isEmpty
                  ? 'No results for "$_query"'
                  : '${filtered.length} result(s)',
              style: AppTypography.caption.copyWith(
                color:
                    filtered.isEmpty
                        ? AppColors.error
                        : widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ),

        // ─── Items list ───
        if (filtered.isEmpty && _query.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No ${widget.title.toLowerCase()} available',
              style: AppTypography.caption,
            ),
          )
        else if (filtered.isEmpty)
          const SizedBox.shrink()
        else
          ...filtered.map((item) {
            final id = widget.idOf(item);
            final isSelected = widget.selectedIds.contains(id);
            return SelectTile(
              isDark: widget.isDark,
              label: widget.labelOf(item),
              subtitle: widget.subtitleOf?.call(item),
              isSelected: isSelected,
              color: widget.activeColor,
              onTap: () => widget.onToggle(item, isSelected),
            );
          }),

        const SizedBox(height: 12),
      ],
    );
  }
}
