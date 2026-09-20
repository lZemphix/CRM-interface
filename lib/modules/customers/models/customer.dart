coclass Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.status,
    required this.acquisitionSourceName,
    this.gender,
    this.dateOfBirth,
    this.primaryContact,
  });

  final int id;
  final String fullName;
  final String status;
  final String acquisitionSourceName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? primaryContact;

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
    );
  }
}
