import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../models/catalog_item.dart';

class CatalogToolbar extends StatelessWidget {
  const CatalogToolbar({
    super.key,
    required this.searchController,
    required this.kind,
    required this.category,
    required this.categories,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onKindChanged,
    required this.onCategoryChanged,
    this.searchFocusNode,
  });

  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final CatalogKind? kind;
  final String? category;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<CatalogKind?> onKindChanged;
  final ValueChanged<String?> onCategoryChanged;

  Widget _types(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Wrap(
      children: [
        for (final value in <CatalogKind?>[null, ...CatalogKind.values])
          TextButton(
            key: ValueKey('catalog-kind-${value?.apiValue ?? 'all'}'),
            style: TextButton.styleFrom(
              backgroundColor: kind == value
                  ? context.colors.surface
                  : Colors.transparent,
              foregroundColor: kind == value
                  ? context.colors.activeElement
                  : context.colors.textMutted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: TextStyle(
                fontSize: 12,
                fontWeight: kind == value ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            onPressed: () => onKindChanged(value),
            child: Text(value?.plural ?? 'Все'),
          ),
      ],
    ),
  );

  Widget _category(BuildContext context) => Container(
    width: 170,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.notActiveBorder),
      borderRadius: BorderRadius.circular(9),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const Key('catalog-category-filter'),
        value: category,
        isExpanded: true,
        isDense: true,
        padding: const EdgeInsets.symmetric(vertical: 11),
        style: TextStyle(fontSize: 12, color: context.colors.taskCardText),
        hint: const Text('Все категории', style: TextStyle(fontSize: 12)),
        items: [
          const DropdownMenuItem<String>(child: Text('Все категории')),
          for (final value in {...categories, ?category})
            DropdownMenuItem(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onCategoryChanged,
      ),
    ),
  );

  Widget _search(BuildContext context) => TextField(
    key: const Key('catalog-search'),
    controller: searchController,
    focusNode: searchFocusNode,
    maxLength: 100,
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(
      isDense: true,
      counterText: '',
      hintText: 'Поиск по названию, категории или артикулу',
      prefixIcon: Icon(Icons.search, size: 18, color: context.colors.textFaint),
      suffixIcon: searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Очистить поиск',
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                searchController.clear();
                onSearchChanged('');
                onSearchSubmitted();
              },
            ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: context.colors.notActiveBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: context.colors.notActiveBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: context.colors.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    ),
    onChanged: onSearchChanged,
    onSubmitted: (_) => onSearchSubmitted(),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final filters = Wrap(
          spacing: 9,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [_types(context), _category(context)],
        );
        return constraints.maxWidth >= 800
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Flexible(
                    child: SizedBox(width: 390, child: _search(context)),
                  ),
                  filters,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [_search(context), filters],
              );
      },
    ),
  );
}
