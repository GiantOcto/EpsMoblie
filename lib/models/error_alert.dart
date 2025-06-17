class ErrorAlert {
  final int id;
  final String title;
  final String errorCode;
  final DateTime timestamp;
  final String severity;
  final String site;

  ErrorAlert({
    required this.id,
    required this.title,
    required this.errorCode,
    required this.timestamp,
    required this.severity,
    required this.site,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  factory ErrorAlert.fromMap(Map<String, dynamic> map) {
    return ErrorAlert(
      id: map['id'] as int,
      title: map['title'] as String,
      errorCode: map['errorCode'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int, isUtc: true).toLocal(),
      severity: map['severity'] as String,
      site: map['site'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'errorCode': errorCode,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'severity': severity,
      'site': site,
    };
  }
} 