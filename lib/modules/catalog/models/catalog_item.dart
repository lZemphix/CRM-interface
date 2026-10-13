import 'package:intl/intl.dart';

enum CatalogKind {
  service('service', 'Услуга', 'Услуги'),
  product('product', 'Товар', 'Товары');

  const CatalogKind(this.apiValue, this.label, this.plural);

  final String apiValue;
  final String label;
  final String plural;

  static CatalogKind fromApi(String value) => values.firstWhere(
    (kind) => kind.apiValue == value,
    orElse: () => throw const FormatException('Unknown catalog kind'),
  );
}

/// NUMERIC(12, 2) stays exact: neither API serialization nor display uses double.
class CatalogPrice {
  const CatalogPrice._(this.kopecks);

  final int kopecks;

  factory CatalogPrice.parse(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,10}(?:\.\d{1,2})?$').hasMatch(normalized)) {
      throw const FormatException('Invalid catalog price');
    }
    final parts = normalized.split('.');
    final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
    return CatalogPrice._(int.parse(parts[0]) * 100 + int.parse(fraction));
  }

  String toApi() =>
      '${kopecks ~/ 100}.${(kopecks % 100).toString().padLeft(2, '0')}';

  String get formatted {
    final rubles = NumberFormat.decimalPattern('ru_RU').format(kopecks ~/ 100);
    final cents = kopecks % 100;
    return '$rubles${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'} ₽';
  }
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.kind,
    required this.category,
    required this.name,
    required this.price,
    required this.description,
    required this.durationMinutes,
    required this.sku,
    required this.isActive,
  });

  final int id;
  final CatalogKind kind;
  final String category;
  final String name;
  final CatalogPrice price;
  final String? description;
  final int? durationMinutes;
  final String? sku;
  final bool isActive;

  factory CatalogItem.fromApi(Map<String, dynamic> data) => CatalogItem(
    id: data['id'] as int,
    kind: CatalogKind.fromApi(data['kind'] as String),
    category: data['category'] as String,
    name: data['name'] as String,
    price: CatalogPrice.parse(data['price'] as String),
    description: data['description'] as String?,
    durationMinutes: data['duration_minutes'] as int?,
    sku: data['sku'] as String?,
    isActive: data['is_active'] as bool,
  );

  String get subtitle => kind == CatalogKind.service
      ? 'Услуга${durationMinutes == null ? '' : ' · $durationMinutes мин'}'
      : 'Товар${sku == null ? '' : ' · $sku'}';
}

class CatalogItemDetails {
  const CatalogItemDetails({required this.item, required this.version});

  final CatalogItem item;
  final int version;

  factory CatalogItemDetails.fromApi(Map<String, dynamic> data) =>
      CatalogItemDetails(
        item: CatalogItem.fromApi(data),
        version: data['version'] as int,
      );
}

class CatalogCounts {
  const CatalogCounts({
    required this.total,
    required this.services,
    required this.products,
  });

  final int total;
  final int services;
  final int products;

  factory CatalogCounts.fromApi(Map<String, dynamic> data) => CatalogCounts(
    total: data['total'] as int,
    services: data['services'] as int,
    products: data['products'] as int,
  );
}

class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.counts,
  });

  final List<CatalogItem> items;
  final int total;
  final int limit;
  final int offset;
  final CatalogCounts counts;

  factory CatalogPage.fromApi(Map<String, dynamic> data) {
    final limit = data['limit'] as int;
    final offset = data['offset'] as int;
    final total = data['total'] as int;
    if (limit < 1 || limit > 100 || offset < 0 || total < 0) {
      throw const FormatException('Invalid catalog pagination');
    }
    return CatalogPage(
      items: List.unmodifiable(
        (data['items'] as List).map(
          (item) => CatalogItem.fromApi(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      total: total,
      limit: limit,
      offset: offset,
      counts: CatalogCounts.fromApi(
        Map<String, dynamic>.from(data['counts'] as Map),
      ),
    );
  }
}
