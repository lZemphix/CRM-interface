import 'create_customer.dart';
import 'customer.dart';

/// null field = omit PATCH key; CustomerFieldChange(null) = explicitly clear it.
class CustomerFieldChange<T> {
  const CustomerFieldChange(this.value);
  final T? value;
}

/// The editable projection. Acquisition/registration facts are not PATCH fields.
class UpdateCustomerRequest {
  const UpdateCustomerRequest({
    required this.version,
    this.fullName,
    this.gender,
    this.dateOfBirth,
    this.homeBranchId,
    this.responsibleEmployeeId,
  });

  final int version;
  final String? fullName;
  final CustomerFieldChange<CustomerGender>? gender;
  final DateTime? dateOfBirth;
  final CustomerFieldChange<int>? homeBranchId;
  final CustomerFieldChange<int>? responsibleEmployeeId;

  Map<String, dynamic> toApi() => {
    'version': version,
    if (fullName != null) 'full_name': fullName,
    if (gender != null) 'gender': gender!.value?.name,
    // A missing legacy birthday is preserved, not explicitly cleared.
    if (dateOfBirth case final date?)
      'date_of_birth':
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
    if (homeBranchId != null) 'home_branch_id': homeBranchId!.value,
    if (responsibleEmployeeId != null)
      'responsible_employee_id': responsibleEmployeeId!.value,
  };
}

class UpdatedCustomerResponse {
  const UpdatedCustomerResponse({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    required this.status,
    required this.responsibleEmployeeId,
    required this.homeBranchId,
    required this.updatedAt,
    required this.version,
  });
  final int id;
  final String fullName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String status;
  final int? responsibleEmployeeId;
  final int? homeBranchId;
  final DateTime updatedAt;
  final int version;

  factory UpdatedCustomerResponse.fromJson(Map<String, dynamic> json) =>
      UpdatedCustomerResponse(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        gender: json['gender'] as String?,
        dateOfBirth: json['date_of_birth'] == null
            ? null
            : DateTime.parse(json['date_of_birth'] as String),
        status: json['status'] as String,
        responsibleEmployeeId: json['responsible_employee_id'] as int?,
        homeBranchId: json['home_branch_id'] as int?,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        version: json['version'] as int,
      );
}

class CustomerEditOptions {
  const CustomerEditOptions({required this.branches, required this.employees});
  final List<CustomerFormOption> branches;
  final List<CustomerFormOption> employees;
}

class WriteCustomerContactRequest {
  const WriteCustomerContactRequest({
    required this.type,
    required this.value,
    required this.label,
    required this.isPrimary,
  });
  final ContactType type;
  final String value;
  final String? label;
  final bool isPrimary;

  Map<String, dynamic> toCreateApi() => {
    'type': type.name,
    'value': value,
    'label': label,
    'is_primary': isPrimary,
  };

  // A contact's type is immutable; changing it means adding another contact.
  Map<String, dynamic> toUpdateApi({required int version}) => {
    'value': value,
    'label': label,
    'is_primary': isPrimary,
    'version': version,
  };
}
