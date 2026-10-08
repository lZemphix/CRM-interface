import 'customer.dart';

enum CustomerGender { female, male, other }

class CreateCustomerContact {
  const CreateCustomerContact({required this.type, required this.value});

  final ContactType type;
  final String value;

  Map<String, dynamic> toApi() => {
    'type': type.name,
    'value': value,
    'is_primary': true,
  };
}

class CreateCustomerRequest {
  const CreateCustomerRequest({
    required this.fullName,
    required this.dateOfBirth,
    required this.acquisitionSourceId,
    required this.contacts,
    this.gender,
    this.homeBranchId,
    this.responsibleEmployeeId,
  });

  final String fullName;
  final DateTime dateOfBirth;
  final int acquisitionSourceId;
  final List<CreateCustomerContact> contacts;
  final CustomerGender? gender;
  final int? homeBranchId;
  final int? responsibleEmployeeId;

  Map<String, dynamic> toApi() => {
    'full_name': fullName,
    // День рождения — календарная дата: перевод в UTC может изменить день.
    'date_of_birth':
        '${dateOfBirth.year.toString().padLeft(4, '0')}-'
        '${dateOfBirth.month.toString().padLeft(2, '0')}-'
        '${dateOfBirth.day.toString().padLeft(2, '0')}',
    'acquisition_source_id': acquisitionSourceId,
    'contacts': contacts.map((contact) => contact.toApi()).toList(),
    if (gender != null) 'gender': gender!.name,
    if (homeBranchId != null) 'home_branch_id': homeBranchId,
    if (responsibleEmployeeId != null)
      'responsible_employee_id': responsibleEmployeeId,
  };
}

class CreatedCustomerResponse {
  const CreatedCustomerResponse({
    required this.id,
    required this.fullName,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String status;
  final DateTime createdAt;

  factory CreatedCustomerResponse.fromJson(Map<String, dynamic> json) {
    return CreatedCustomerResponse(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Проекция справочника для выбора в форме, а не полная модель сущности.
class CustomerFormOption {
  const CustomerFormOption({required this.id, required this.name});

  final int id;
  final String name;
}

class CustomerCreationOptions {
  const CustomerCreationOptions({
    required this.sources,
    required this.branches,
    required this.employees,
  });

  final List<CustomerFormOption> sources;
  final List<CustomerFormOption> branches;
  final List<CustomerFormOption> employees;
}
