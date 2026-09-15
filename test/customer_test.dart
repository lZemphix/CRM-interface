import 'package:crm_interface/modules/customers/models/customer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
