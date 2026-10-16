import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../models/catalog_item.dart';

class CatalogListHeader extends StatelessWidget {
  const CatalogListHeader({super.key, required this.showCategory});

  final bool showCategory;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: context.colors.background,
    child: DefaultTextStyle(
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colors.textMutted,
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

  Widget _name(BuildContext context) => Row(
    spacing: 12,
    children: [
      Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: item.kind == CatalogKind.service
              ? context.colors.accentSoft
              : context.colors.successSoft,
        ),
        child: Text(
          item.kind == CatalogKind.service ? 'У' : 'Т',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: item.kind == CatalogKind.service
                ? context.colors.activeElement
                : context.colors.success,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.taskCardText,
                ),
              ),
            ),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.colors.textFaint),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _status(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: item.isActive
            ? context.colors.successSoft
            : context.colors.surfaceMuted,
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
                  ? context.colors.success
                  : context.colors.textMutted,
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
                    ? context.colors.success
                    : context.colors.textMutted,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actions(BuildContext context) => Row(
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
        icon: Icon(
          Icons.edit_outlined,
          size: 17,
          color: context.colors.textMutted,
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
        icon: Icon(Icons.close, size: 18, color: context.colors.textMutted),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final price = Text(
      item.price.formatted,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.colors.taskCardText,
      ),
    );
    return Material(
      color: context.colors.surface,
      child: InkWell(
        hoverColor: context.colors.background,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.colors.notActiveBorder),
            ),
          ),
          child: compact
              ? Column(
                  spacing: 10,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _name(context)),
                        _status(context),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textMutted,
                                ),
                              ),
                              price,
                            ],
                          ),
                        ),
                        _actions(context),
                      ],
                    ),
                  ],
                )
              : Row(
                  spacing: 14,
                  children: [
                    Expanded(flex: 23, child: _name(context)),
                    if (showCategory)
                      Expanded(
                        flex: 10,
                        child: Text(
                          item.category,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMutted,
                          ),
                        ),
                      ),
                    SizedBox(width: 115, child: price),
                    SizedBox(width: 100, child: _status(context)),
                    SizedBox(
                      width: 80,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _actions(context),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
