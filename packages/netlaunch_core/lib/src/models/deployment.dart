class Deployment {
  final String id;
  final String apiKey;
  final String subdomain;
  final String url;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? filePath;
  final Map<String, dynamic>? metadata;
  final String? error;

  Deployment({
    required this.id,
    required this.apiKey,
    required this.subdomain,
    required this.url,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.filePath,
    this.metadata,
    this.error,
  });

  factory Deployment.fromMap(Map<String, dynamic> map, String id) {
    return Deployment(
      id: id,
      apiKey: map['apiKey'] ?? '',
      subdomain: map['subdomain'] ?? map['siteName'] ?? '',
      url: map['url'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      filePath: map['filePath'],
      metadata: map['metadata'],
      error: map['error'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'subdomain': subdomain,
      'url': url,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'filePath': filePath,
      'metadata': metadata,
      'error': error,
    };
  }
}
