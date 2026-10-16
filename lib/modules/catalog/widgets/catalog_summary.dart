import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../models/catalog_item.dart';

class CatalogSummary extends StatelessWidget {
  const CatalogSummary({super.key, required this.counts});

  final CatalogCounts? counts;

  Widget _stat(BuildContext context, String label, int? value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.notActiveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.textMutted),
          ),
          Text(
            value?.toString() ?? '—',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: context.colors.taskCardText,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'С учётом поиска и категории, по всем типам позиций',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        _stat(context, 'Всего позиций', counts?.total),
        _stat(context, 'Услуги', counts?.services),
        _stat(context, 'Товары', counts?.products),
      ],
    ),
  );
}
