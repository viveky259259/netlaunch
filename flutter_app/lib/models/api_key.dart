import 'package:cloud_firestore/cloud_firestore.dart';

class ApiKey {
  final String key;
  final DateTime? createdAt;
  final int? usageCount;
  final DateTime? lastUsed;

  ApiKey({
    required this.key,
    this.createdAt,
    this.usageCount,
    this.lastUsed,
  });

  factory ApiKey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApiKey(
      key: data['key'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      usageCount: data['usageCount'] as int?,
      lastUsed: _parseTimestamp(data['lastUsed']),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
