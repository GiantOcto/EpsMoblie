class ServerStatus {
  final bool isHealthy;
  final int responseTime;
  final double uptime;

  ServerStatus({
    required this.isHealthy,
    required this.responseTime,
    required this.uptime,
  });

  factory ServerStatus.fromMap(Map<String, dynamic> map) {
    return ServerStatus(
      isHealthy: map['isHealthy'] as bool,
      responseTime: map['responseTime'] as int,
      uptime: (map['uptime'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isHealthy': isHealthy,
      'responseTime': responseTime,
      'uptime': uptime,
    };
  }
} 