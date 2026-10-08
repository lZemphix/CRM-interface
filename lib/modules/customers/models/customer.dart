import 'customer_note.dart';

class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.status,
    required this.acquisitionSourceName,
    this.gender,
    this.dateOfBirth,
    this.primaryContact,
    this.responsible,
  });

  final int id;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String status;
  final String? primaryContact;
  final String acquisitionSourceName;
  final CustomerEmployee? responsible;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final rawDateOfBirth = json['date_of_birth'] as String?;

    return Customer(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      status: json['status'] as String,
      acquisitionSourceName: json['acquisition_source_name'] as String,
      gender: json['gender'] as String?,
      dateOfBirth: rawDateOfBirth == null
          ? null
          : DateTime.parse(rawDateOfBirth),
      primaryContact: json['primary_contact'] as String?,
      responsible: CustomerEmployee.nullableFromJson(json['responsible']),
    );
  }
}

class CustomerDetails {
  const CustomerDetails({
    required this.id,
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    required this.status,
    this.responsibleEmployeeId,
    this.createdByEmployeeId,
    this.responsible,
    this.createdBy,
    this.homeBranchId,
    required this.acquisitionSourceId,
    required this.acquisitionSourceCode,
    required this.acquisitionSourceName,
    required this.registrationMethod,
    this.referredByCustomerId,
    required this.createdAt,
    required this.updatedAt,
    required this.contacts,
    required this.notes,
  });

  final int id;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String status;
  final int? responsibleEmployeeId;
  final int? createdByEmployeeId;
  final CustomerEmployee? responsible;
  final CustomerEmployee? createdBy;
  final int? homeBranchId;
  final int acquisitionSourceId;
  final String acquisitionSourceCode;
  final String acquisitionSourceName;
  final RegistrationMethod registrationMethod;
  final int? referredByCustomerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CustomerContact> contacts;
  final List<CustomerNote> notes;

  factory CustomerDetails.fromJson(Map<String, dynamic> json) {
    final rawDateOfBirth = json['date_of_birth'] as String?;
    final rawContacts = json['contacts'] as List<dynamic>;

    return CustomerDetails(
      id: json['id'],
      fullName: json['full_name'] as String,
      gender: json['gender'] as String?,
      dateOfBirth: rawDateOfBirth == null
          ? null
          : DateTime.parse(rawDateOfBirth),
      status: json['status'] as String,
      responsibleEmployeeId: json['responsible_employee_id'] as int?,
      createdByEmployeeId: json['created_by_employee_id'] as int?,
      responsible: CustomerEmployee.nullableFromJson(json['responsible']),
      createdBy: CustomerEmployee.nullableFromJson(json['created_by']),
      homeBranchId: json['home_branch_id'] as int?,
      acquisitionSourceId: json['acquisition_source_id'] as int,
      acquisitionSourceCode: json['acquisition_source_code'] as String,
      acquisitionSourceName: json['acquisition_source_name'] as String,
      registrationMethod: RegistrationMethod.fromApi(
        json['registration_method'] as String,
      ),
      referredByCustomerId: json['referred_by_customer_id'] as int?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      contacts: rawContacts
          .map(
            (data) => CustomerContact.fromJson(
              Map<String, dynamic>.from(data as Map),
            ),
          )
          .toList(),
      notes: (json['notes'] as List)
          .map(
            (note) =>
                CustomerNote.fromJson(Map<String, dynamic>.from(note as Map)),
          )
          .toList(),
    );
  }
}

class CustomerEmployee {
  const CustomerEmployee({required this.id, required this.fullName});
  final int id;
  final String fullName;

  factory CustomerEmployee.fromJson(Map<String, dynamic> json) =>
      CustomerEmployee(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
      );

  static CustomerEmployee? nullableFromJson(Object? json) => json == null
      ? null
      : CustomerEmployee.fromJson(Map<String, dynamic>.from(json as Map));
}

class CustomerContact {
  const CustomerContact({
    required this.id,
    required this.type,
    required this.value,
    this.label,
    required this.isPrimary,
    required this.createdAt,
  });

  final int id;
  final ContactType type;
  final String value;
  final String? label;
  final bool isPrimary;
  final DateTime createdAt;

  factory CustomerContact.fromJson(Map<String, dynamic> json) {
    return CustomerContact(
      id: json['id'] as int,
      type: ContactType.fromApi(json['type'] as String),
      value: json['value'] as String,
      label: json['label'] as String?,
      isPrimary: json['is_primary'] as bool,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

enum ContactType {
  phone,
  email,
  telegram,
  max,
  other,
  unknown;

  static ContactType fromApi(String value) {
    return switch (value) {
      'phone' => ContactType.phone,
      'email' => ContactType.email,
      'telegram' => ContactType.telegram,
      'max' => ContactType.max,
      'other' => ContactType.other,
      _ => ContactType.unknown,
    };
  }
}

enum RegistrationMethod {
  employee,
  selfService,
  import,
  integration,
  unknown;

  static RegistrationMethod fromApi(String value) {
    return switch (value) {
      'employee' => RegistrationMethod.employee,
      'self_service' || 'selfService' => RegistrationMethod.selfService,
      'import' => RegistrationMethod.import,
      'integration' => RegistrationMethod.integration,
      _ => RegistrationMethod.unknown,
    };
  }
}
