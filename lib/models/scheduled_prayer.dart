class ScheduledPrayer {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String category;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool isActive;

  ScheduledPrayer({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.category = 'general',
    this.payload = const {},
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create a copy with updated fields
  ScheduledPrayer copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? scheduledTime,
    String? category,
    Map<String, dynamic>? payload,
    bool? isActive,
  }) {
    return ScheduledPrayer(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      category: category ?? this.category,
      payload: payload ?? this.payload,
      createdAt: this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'category': category,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // JSON deserialization
  factory ScheduledPrayer.fromJson(Map<String, dynamic> json) {
    return ScheduledPrayer(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      scheduledTime: DateTime.parse(json['scheduledTime'] ?? DateTime.now().toIso8601String()),
      category: json['category'] ?? 'general',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
    );
  }

  @override
  String toString() {
    return 'ScheduledPrayer(id: $id, title: $title, scheduledTime: $scheduledTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledPrayer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}