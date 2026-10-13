import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

import '../models/catalog_item.dart';

class CatalogListHeader extends StatelessWidget {
  const CatalogListHeader({super.key, required this.showCategory});

  final bool showCategory;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: const Color(0xFFF9FAFB),
    child: DefaultTextStyle(
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMutted,
      ),
      child: Row(
        spacing: 14,
        children: [
          const Expanded(flex: 23, child: Text('Название')),
          if (showCategory) const Expanded(flex: 10, child: Text('Категория')),
          const SizedBox(width: 115, child: Text('Цена')),
          const SizedBox(width: 100, child: Text('Статус')),
          const SizedBox(width: 80),
        ],
      ),
    ),
  );
}

class CatalogRow extends StatelessWidget {
  const CatalogRow({
    super.key,
    required this.item,
    required this.showCategory,
    required this.compact,
    required this.onEdit,
    required this.onArchive,
  });

  final CatalogItem item;
  final bool showCategory;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  Widget _name() => Row(
    spacing: 12,
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: item.kind == CatalogKind.service
              ? const Color(0xFFEEEEFF)
              : const Color(0xFFE7F5EE),
        ),
        child: Text(
          item.kind == CatalogKind.service ? 'У' : 'Т',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: item.kind == CatalogKind.service
                ? AppColors.activeElement
                : const Color(0xFF21865D),
          ),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Tooltip(
              message: item.description ?? item.name,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.taskCardText,
                ),
              ),
            ),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _status() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: item.isActive
            ? const Color(0xFFECFDF3)
            : const Color(0xFFF2F4F7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isActive
                  ? const Color(0xFF027A48)
                  : AppColors.textMutted,
            ),
          ),
          Flexible(
            child: Text(
              item.isActive ? 'Доступна' : 'Скрыта',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: item.isActive
                    ? const Color(0xFF027A48)
                    : AppColors.textMutted,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: ValueKey('catalog-edit-${item.id}'),
        tooltip: 'Редактировать «${item.name}»',
        onPressed: onEdit,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          fixedSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.edit_outlined,
          size: 17,
          color: AppColors.textMutted,
        ),
      ),
      IconButton(
        key: ValueKey('catalog-archive-${item.id}'),
        tooltip: 'Архивировать «${item.name}»',
        onPressed: onArchive,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          fixedSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close, size: 18, color: AppColors.textMutted),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final price = Text(
      item.price.formatted,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.taskCardText,
      ),
    );
    return Material(
      color: Colors.white,
      child: InkWell(
        hoverColor: const Color(0xFFFCFCFF),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5))),
          ),
          child: compact
              ? Column(
                  spacing: 10,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _name()),
                        _status(),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMutted,
                                ),
                              ),
                              price,
                            ],
                          ),
                        ),
                        _actions(),
                      ],
                    ),
                  ],
                )
              : Row(
                  spacing: 14,
                  children: [
                    Expanded(flex: 23, child: _name()),
                    if (showCategory)
                      Expanded(
                        flex: 10,
                        child: Text(
                          item.category,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutted,
                          ),
                        ),
                      ),
                    SizedBox(width: 115, child: price),
                    SizedBox(width: 100, child: _status()),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _actions(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
