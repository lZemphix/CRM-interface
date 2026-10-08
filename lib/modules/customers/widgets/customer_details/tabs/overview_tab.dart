import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Icon getContactIcon(CustomerContact contact) {
  switch (contact.type) {
    case ContactType.phone:
      return Icon(Icons.phone_outlined, color: AppColors.textMutted, size: 15);
    case ContactType.email:
      return Icon(
        Icons.mail_lock_outlined,
        color: AppColors.textMutted,
        size: 15,
      );
    case ContactType.telegram:
      return Icon(Icons.telegram, color: AppColors.textMutted, size: 15);
    case ContactType.max:
      return Icon(
        Icons.chat_bubble_outline_rounded,
        color: AppColors.textMutted,
        size: 15,
      );
    case ContactType.other:
      return Icon(
        Icons.contact_page_outlined,
        color: AppColors.textMutted,
        size: 15,
      );
    case ContactType.unknown:
      return Icon(
        Icons.help_center_outlined,
        color: AppColors.textMutted,
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
        children: [aboutCustomer(customer, branchLabel), contacts(customer)],
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

Widget aboutCustomerElement(String key, String value) {
  return Row(
    children: [
      Expanded(
        child: Text(
          key,
          style: TextStyle(fontSize: 13, color: AppColors.textMutted),
        ),
      ),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13))),
    ],
  );
}

Widget aboutCustomer(CustomerDetails customer, String branchLabel) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.notActiveBorder),
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
              onPressed: null,
              child: Text(
                'Изменить',
                style: TextStyle(color: AppColors.activeElement),
              ),
            ),
          ],
        ),
        Column(
          spacing: 10,
          children: [
            aboutCustomerElement(
              'Пол',
              getGenderTranslate(customer.gender ?? '_'),
            ),
            aboutCustomerElement(
              'Дата рождения',
              customer.dateOfBirth == null
                  ? 'Не указана'
                  : DateFormat('dd.MM.yyyy').format(customer.dateOfBirth!),
            ),
            aboutCustomerElement('Предпочитаемый филиал', branchLabel),
            aboutCustomerElement('Источник', customer.acquisitionSourceName),
            aboutCustomerElement(
              'Рекомендовал',
              customer.referredByCustomerId == null
                  ? 'Не указан'
                  : 'Клиент #${customer.referredByCustomerId}',
            ),
            aboutCustomerElement(
              'Способ регистрации',
              getRegistrationMethodTranslate(customer.registrationMethod),
            ),
            aboutCustomerElement(
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

Widget contactElement(Icon icon, String key, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      icon,
      const SizedBox(width: 10),
      Expanded(
        child: SelectableText(
          value,
          style: TextStyle(fontWeight: FontWeight(400)),
        ),
      ),
      const SizedBox(width: 10),
      Text(key, style: TextStyle(color: AppColors.textMutted)),
    ],
  );
}

Widget contacts(CustomerDetails customer) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.notActiveBorder),
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
              onPressed: null,
              child: Text(
                '+ добавить',
                style: TextStyle(color: AppColors.activeElement),
              ),
            ),
          ],
        ),
        if (customer.contacts.isEmpty) const Text('Контакты не указаны'),
        for (CustomerContact contact in customer.contacts)
          contactElement(
            getContactIcon(contact),
            contact.isPrimary ? 'Основной' : 'Запасной',
            contact.value.trim(),
          ),
      ],
    ),
  );
}
