import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

import '../models/catalog_item.dart';

class CatalogSummary extends StatelessWidget {
  const CatalogSummary({super.key, required this.counts});

  final CatalogCounts? counts;

  Widget _stat(String label, int? value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.notActiveBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMutted),
          ),
          Text(
            value?.toString() ?? '—',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: AppColors.taskCardText,
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
        _stat('Всего позиций', counts?.total),
        _stat('Услуги', counts?.services),
        _stat('Товары', counts?.products),
      ],
    ),
  );
}
