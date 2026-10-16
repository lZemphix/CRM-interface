import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Icon getContactIcon(BuildContext context, CustomerContact contact) {
  switch (contact.type) {
    case ContactType.phone:
      return Icon(
        Icons.phone_outlined,
        color: context.colors.textMutted,
        size: 15,
      );
    case ContactType.email:
      return Icon(
        Icons.mail_lock_outlined,
        color: context.colors.textMutted,
        size: 15,
      );
    case ContactType.telegram:
      return Icon(Icons.telegram, color: context.colors.textMutted, size: 15);
    case ContactType.max:
      return Icon(
        Icons.chat_bubble_outline_rounded,
        color: context.colors.textMutted,
        size: 15,
      );
    case ContactType.other:
      return Icon(
        Icons.contact_page_outlined,
        color: context.colors.textMutted,
        size: 15,
      );
    case ContactType.unknown:
      return Icon(
        Icons.help_center_outlined,
        color: context.colors.textMutted,
        size: 15,
      );
  }
}

String getGenderTranslate(String gender) {
  switch (gender) {
    case 'male':
      return 'мужской';
    case 'female':
      return 'женский';
    case 'other':
      return 'другой';
    case _:
      return 'не указан';
  }
}

String getRegistrationMethodTranslate(RegistrationMethod method) {
  switch (method) {
    case RegistrationMethod.employee:
      return 'Сотрудником';
    case RegistrationMethod.import:
      return 'Импорт';
    case RegistrationMethod.selfService:
      return 'Самостоятельно';
    case RegistrationMethod.integration:
      return 'Интеграция';
    case RegistrationMethod.unknown:
      return 'Неизвестно';
  }
}

Widget overviewTab(
  CustomerDetails customer, {
  required Widget nextTask,
  required Widget recentActivity,
  required String branchLabel,
  VoidCallback? onEditCustomer,
  VoidCallback? onEditContacts,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final main = Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [nextTask, recentActivity],
      );
      final info = Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          aboutCustomer(context, customer, branchLabel, onEdit: onEditCustomer),
          contacts(context, customer, onEdit: onEditContacts),
        ],
      );
      return SingleChildScrollView(
        child: constraints.maxWidth < 820
            ? Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [main, info],
              )
            : Row(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: main),
                  Expanded(child: info),
                ],
              ),
      );
    },
  );
}

Widget aboutCustomerElement(BuildContext context, String key, String value) {
  return Row(
    children: [
      Expanded(
        child: Text(
          key,
          style: TextStyle(fontSize: 13, color: context.colors.textMutted),
        ),
      ),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13))),
    ],
  );
}

Widget aboutCustomer(
  BuildContext context,
  CustomerDetails customer,
  String branchLabel, {
  VoidCallback? onEdit,
}) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.notActiveBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      spacing: 10,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'О клиенте',
                style: TextStyle(fontWeight: FontWeight(500)),
              ),
            ),
            TextButton(
              key: const Key('edit-customer-about'),
              onPressed: onEdit,
              child: Text(
                'Изменить',
                style: TextStyle(color: context.colors.accent),
              ),
            ),
          ],
        ),
        Column(
          spacing: 10,
          children: [
            aboutCustomerElement(
              context,
              'Пол',
              getGenderTranslate(customer.gender ?? '_'),
            ),
            aboutCustomerElement(
              context,
              'Дата рождения',
              customer.dateOfBirth == null
                  ? 'Не указана'
                  : DateFormat('dd.MM.yyyy').format(customer.dateOfBirth!),
            ),
            aboutCustomerElement(context, 'Предпочитаемый филиал', branchLabel),
            aboutCustomerElement(
              context,
              'Источник',
              customer.acquisitionSourceName,
            ),
            aboutCustomerElement(
              context,
              'Рекомендовал',
              customer.referredByCustomerId == null
                  ? 'Не указан'
                  : 'Клиент #${customer.referredByCustomerId}',
            ),
            aboutCustomerElement(
              context,
              'Способ регистрации',
              getRegistrationMethodTranslate(customer.registrationMethod),
            ),
            aboutCustomerElement(
              context,
              'Создавший сотрудник',
              customer.createdBy?.fullName ??
                  (customer.createdByEmployeeId == null
                      ? 'Не указан'
                      : 'Сотрудник #${customer.createdByEmployeeId}'),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget contactElement(
  BuildContext context,
  Icon icon,
  String key,
  String value, {
  String? label,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      icon,
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              value,
              style: TextStyle(fontWeight: FontWeight(400)),
            ),
            if (label != null)
              Text(
                label,
                style: TextStyle(
                  color: context.colors.textMutted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Text(key, style: TextStyle(color: context.colors.textMutted)),
    ],
  );
}

Widget contacts(
  BuildContext context,
  CustomerDetails customer, {
  VoidCallback? onEdit,
}) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.notActiveBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      spacing: 10,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Контакты',
                style: TextStyle(fontWeight: FontWeight(500)),
              ),
            ),
            TextButton(
              key: const Key('edit-customer-contacts'),
              onPressed: onEdit,
              child: Text(
                'Изменить',
                style: TextStyle(color: context.colors.accent),
              ),
            ),
          ],
        ),
        if (customer.contacts.isEmpty) const Text('Контакты не указаны'),
        for (CustomerContact contact in customer.contacts)
          contactElement(
            context,
            getContactIcon(context, contact),
            contact.isPrimary ? 'Основной' : 'Запасной',
            contact.value.trim(),
            label: contact.label,
          ),
      ],
    ),
  );
}
