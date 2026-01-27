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
}

