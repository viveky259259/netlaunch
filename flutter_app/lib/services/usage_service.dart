import 'package:cloud_firestore/cloud_firestore.dart';

class UsageStats {
  final int totalDeployments;
  final int activeDeployments;
  final int failedDeployments;
  final int pendingDeployments;
  final DateTime? lastDeployedAt;

  UsageStats({
    required this.totalDeployments,
    required this.activeDeployments,
    required this.failedDeployments,
    required this.pendingDeployments,
    this.lastDeployedAt,
  });

  double get successRate =>
      totalDeployments > 0 ? (activeDeployments / totalDeployments) * 100 : 0;
}

class ApiKeyInfo {
  final String id;
  final String keyHash;
  final int usageCount;
  final DateTime? lastUsed;
  final DateTime createdAt;

  ApiKeyInfo({
    required this.id,
    required this.keyHash,
    required this.usageCount,
    this.lastUsed,
    required this.createdAt,
  });

  factory ApiKeyInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApiKeyInfo(
      id: doc.id,
      keyHash: data['keyHash'] ?? doc.id.substring(0, 8),
      usageCount: data['usageCount'] ?? 0,
      lastUsed: _parseTimestamp(data['lastUsed']),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class UsageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ApiKeyInfo>> getUserApiKeys(String userId) async {
    final snapshot = await _firestore
        .collection('apiKeys')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => ApiKeyInfo.fromFirestore(doc)).toList();
  }
}
