class ComplaintModel {
  ComplaintModel({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String status;
  final int createdAt;

  factory ComplaintModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    int integer(String key) {
      return int.tryParse((map[key] ?? 0).toString()) ?? 0;
    }

    return ComplaintModel(
      id: id,
      title: text('title', 'Complaint'),
      message: text('message', text('description')),
      status: text('status', 'open').toLowerCase(),
      createdAt: integer('createdAt'),
    );
  }
}