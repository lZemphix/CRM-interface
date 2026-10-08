class CustomerNote {
  const CustomerNote({
    required this.id,
    required this.authorEmployeeId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.editedAt,
    required this.version,
  });

  final int id;
  final int authorEmployeeId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int version;

  factory CustomerNote.fromJson(Map<String, dynamic> json) {
    final author = Map<String, dynamic>.from(json['author'] as Map);
    return CustomerNote(
      id: json['id'] as int,
      authorEmployeeId: json['author_employee_id'] as int,
      authorName: author['full_name'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      version: json['version'] as int,
    );
  }
}

class CreateCustomerNoteRequest {
  const CreateCustomerNoteRequest({required this.text});

  final String text;

  Map<String, dynamic> toApi() => {'text': text.trim()};
}

class UpdateCustomerNoteRequest {
  const UpdateCustomerNoteRequest({required this.text, required this.version});

  final String text;
  final int version;

  Map<String, dynamic> toApi() => {'text': text.trim(), 'version': version};
}
