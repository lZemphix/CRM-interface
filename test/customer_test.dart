import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reads nested employees and the real self_service registration method',
    () {
      final customer = Customer.fromJson({
        'id': 1,
        'full_name': 'Анна',
        'status': 'active',
        'acquisition_source_name': 'Сайт',
        'responsible': {'id': 4, 'full_name': 'Ответственный'},
      });
      expect(customer.responsible!.fullName, 'Ответственный');
      final details = CustomerDetails.fromJson({
        'id': 1,
        'full_name': 'Анна',
        'status': 'active',
        'responsible_employee_id': 4,
        'created_by_employee_id': 5,
        'responsible': {'id': 4, 'full_name': 'Ответственный'},
        'created_by': {'id': 5, 'full_name': 'Создавший'},
        'acquisition_source_id': 1,
        'acquisition_source_code': 'site',
        'acquisition_source_name': 'Сайт',
        'registration_method': 'self_service',
        'created_at': '2026-10-08T00:00:00Z',
        'updated_at': '2026-10-08T00:00:00Z',
        'contacts': [],
        'notes': [],
      });
      expect(details.createdBy!.fullName, 'Создавший');
      expect(details.responsible!.id, 4);
      expect(details.registrationMethod, RegistrationMethod.selfService);
    },
  );
  test('creates a customer from the backend response', () {
    final customer = Customer.fromJson({
      'id': 10,
      'full_name': 'Артём Васильев',
      'gender': 'male',
      'date_of_birth': '1997-08-16',
      'status': 'active',
      'primary_contact': '+79990000010',
      'acquisition_source_name': 'Рекомендация',
    });

    expect(customer.id, 10);
    expect(customer.fullName, 'Артём Васильев');
    expect(customer.dateOfBirth, DateTime(1997, 8, 16));
    expect(customer.primaryContact, '+79990000010');
  });
}
