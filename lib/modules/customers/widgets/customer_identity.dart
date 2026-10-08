import 'package:flutter/widgets.dart';

import '../models/customer.dart';

String customerNameIcon(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  return words.isEmpty
      ? '?'
      : words.map((word) => word.characters.first).join().toUpperCase();
}

String getPrimaryContact(List<CustomerContact> contacts) {
  final available = contacts.where(
    (contact) => contact.value.trim().isNotEmpty,
  );
  final contact =
      available.where((contact) => contact.isPrimary).firstOrNull ??
      available
          .where((contact) => contact.type == ContactType.phone)
          .firstOrNull ??
      available.firstOrNull;
  return contact?.value.trim() ?? 'Контакт не указан';
}

String customerResponsibleLabel(CustomerDetails customer) =>
    customer.responsible?.fullName ??
    (customer.responsibleEmployeeId == null
        ? 'Не назначен'
        : 'Сотрудник #${customer.responsibleEmployeeId}');
