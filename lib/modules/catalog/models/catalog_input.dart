import 'catalog_item.dart';

class CatalogItemInput {
  const CatalogItemInput({
    required this.kind,
    required this.category,
    required this.name,
    required this.price,
    required this.description,
    required this.durationMinutes,
    required this.sku,
    required this.isActive,
  });

  final CatalogKind kind;
  final String category;
  final String name;
  final CatalogPrice price;
  final String? description;
  final int? durationMinutes;
  final String? sku;
  final bool isActive;

  Map<String, dynamic> _fields() => {
    'category': category.trim(),
    'name': name.trim(),
    'price': price.toApi(),
    'description': description,
    'is_active': isActive,
    if (kind == CatalogKind.service) 'duration_minutes': durationMinutes,
    if (kind == CatalogKind.product) 'sku': sku,
  };

  Map<String, dynamic> toCreateApi() => {'kind': kind.apiValue, ..._fields()};

  // kind is immutable; branch-specific terms are deliberately not part of this form.
  Map<String, dynamic> toUpdateApi(int version) => {
    ..._fields(),
    'version': version,
  };
}
