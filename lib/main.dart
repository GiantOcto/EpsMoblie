import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// 🔥 백그라운드 서비스 채널
const platform = MethodChannel('background_service');

// 전역 알림 플러그인
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 알림 서비스 초기화
  await NotificationService.initialize();
  
  print('🔥 ===== 서버 24시간 감시 시작! =====');
  
  // 🔥 백그라운드 서비스 시작!
  try {
    await platform.invokeMethod('startBackgroundService');
    print('🚀 백그라운드 감시 서비스 시작됨!');
  } catch (e) {
    print('❌ 백그라운드 서비스 실패: $e');
  }
  
  print('🔋 배터리 최적화 완전 무시!');
  print('📱 앱을 완전히 종료해도 계속 실행됩니다!');
  print('⏰ 1분마다 백그라운드에서 알림이 생성됩니다!');
  
  runApp(const ServerMonitorApp());
}

class NotificationService {
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('알림 클릭됨: ${response.payload}');
      },
    );
    
    await _requestPermissions();
  }
  
  static Future<void> _requestPermissions() async {
    // 모든 필요한 권한 요청
    await Permission.notification.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.systemAlertWindow.request();
    
    print('📱 모든 권한 요청 완료');
  }
  
  static Future<void> showErrorNotification({
    required String title,
    required String errorCode,
    required String body,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'app_error_channel',
      '앱 내 서버 에러',
      channelDescription: '앱이 실행 중일 때 발생한 서버 에러',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFF0000),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 300]),
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚨 에러 발생: $errorCode',
      title,
      platformChannelSpecifics,
      payload: errorCode,
    );
  }
}

class ErrorAlert {
  final int id;  // 🔥 DB ID 추가
  final String title;
  final String errorCode;
  final DateTime timestamp;
  final String severity;

  ErrorAlert({
    required this.id,
    required this.title,
    required this.errorCode,
    required this.timestamp,
    required this.severity,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class ServerStatus {
  final bool isHealthy;
  final int responseTime;
  final double uptime;

  ServerStatus({
    required this.isHealthy,
    required this.responseTime,
    required this.uptime,
  });
}

class ServerMonitorApp extends StatefulWidget {
  const ServerMonitorApp({Key? key}) : super(key: key);

  @override
  State<ServerMonitorApp> createState() => _ServerMonitorAppState();
}

class _ServerMonitorAppState extends State<ServerMonitorApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPS Moblie',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DashboardScreen(
        isDarkMode: isDarkMode,
        onThemeToggle: toggleTheme,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const DashboardScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Timer? _errorTimer;
  Timer? _statusTimer;
  List<ErrorAlert> _errors = [];
  ServerStatus _serverStatus = ServerStatus(isHealthy: true, responseTime: 120, uptime: 99.9);
  final Random _random = Random();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  int _currentIndex = 0;  // 🔥 하단 네비게이션 인덱스

  final List<String> _errorMessages = [
    'CPU 사용률 95% 초과',
    'Database 연결 실패',
    '메모리 부족 (임계치 초과)',
    'API 응답 시간 초과',
    '디스크 용량 부족',
    'Network 연결 불안정',
    'SSL 인증서 만료 임박',
    'Redis 캐시 오류',
    'Load Balancer 응답 없음',
    'Background Job 실패',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _startErrorGeneration();
    _startStatusUpdates();
  }

  void _initializeData() {
    _errors = [];
    // 🔥 데이터베이스에서 기존 에러들 불러오기
    _loadErrorsFromDatabase();
  }

  void _startErrorGeneration() {
    // 🔥 앱 UI에서는 에러 생성 안함 (백그라운드에서만)
    // 대신 주기적으로 DB에서 새로운 에러 체크
    _errorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadErrorsFromDatabase();
    });
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      _updateServerStatus();
    });
  }

  void _loadErrorsFromDatabase() async {
    try {
      final result = await platform.invokeMethod('getErrorsFromDB');
      final List<dynamic> errorData = result as List<dynamic>;
      
      final List<ErrorAlert> newErrors = errorData.map((data) {
        final Map<String, dynamic> errorMap = Map<String, dynamic>.from(data);
        return ErrorAlert(
          id: errorMap['id'] as int,
          title: errorMap['title'] as String,
          errorCode: errorMap['errorCode'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(errorMap['timestamp'] as int),
          severity: errorMap['severity'] as String,
        );
      }).toList();
      
      // 🔥 새로운 에러가 있으면 UI 업데이트
      if (newErrors.length != _errors.length) {
        final oldCount = _errors.length;
        final newCount = newErrors.length;
        
        setState(() {
          _errors = newErrors;
        });
        
        print('📱 DB에서 ${newErrors.length}개 에러 로드됨 (이전: $oldCount개)');
        
        // 🔥 새 에러가 추가되었을 때 애니메이션 처리
        if (newCount > oldCount) {
          // 새로 추가된 에러들에 대해 애니메이션 적용
          for (int i = 0; i < (newCount - oldCount); i++) {
            _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 300));
          }
          
          _playErrorSound();
          _triggerVibration();
        }
      }
    } catch (e) {
      print('❌ DB 에러 로드 실패: $e');
    }
  }

  void _generateNewError() async {
    // 🔥 이 함수는 더 이상 사용하지 않음 (백그라운드에서 처리)
    // 백그라운드 서비스에서 DB에 저장하면 _loadErrorsFromDatabase()에서 자동으로 로드됨
  }

  void _updateServerStatus() async {
    setState(() {
      _serverStatus = ServerStatus(
        isHealthy: true, // 항상 정상 상태
        responseTime: 85, // 고정된 좋은 응답 시간
        uptime: 99.9, // 고정된 높은 업타임
      );
    });
  }

  void _playErrorSound() async {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('사운드 재생 실패: $e');
    }
  }

  void _triggerVibration() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 500, 200, 300]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('진동 실행 실패: $e');
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errorTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'EPS Moblie' : '에러 통계'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Switch(
                value: widget.isDarkMode,
                onChanged: (value) => widget.onThemeToggle(),
                activeColor: Colors.grey[800],
                activeTrackColor: Colors.grey[600],
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildDashboard() : _buildStatistics(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: '통계',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '서버 상태',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ServerStatusCard(serverStatus: _serverStatus),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 알림',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '총 ${_errors.length}개',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RecentAlertsWidget(
            errors: _errors,
            listKey: _listKey,
            onErrorHide: _hideError,
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return const StatisticsPage();
  }

  void _hideError(int errorId) async {
    try {
      // 🔥 데이터베이스에서 숨김 처리
      await platform.invokeMethod('hideError', {'errorId': errorId});
      
      // 🔥 UI에서 즉시 제거
      setState(() {
        _errors.removeWhere((error) => error.id == errorId);
      });
      
      print('🙈 에러 숨김 처리 완료: ID=$errorId');
    } catch (e) {
      print('❌ 에러 숨김 실패: $e');
    }
  }
}

// 🔥 통계 페이지
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() async {
    try {
      final result = await platform.invokeMethod('getErrorStatistics');
      setState(() {
        _statistics = _convertToStringDynamic(result);
        _isLoading = false;
      });
      print('📊 통계 데이터 로드 완료');
    } catch (e) {
      print('❌ 통계 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _convertToStringDynamic(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data.map((key, value) {
        if (value is List) {
          return MapEntry(key.toString(), value.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return item;
          }).toList());
        }
        return MapEntry(key.toString(), value);
      }));
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_statistics == null) {
      return const Center(
        child: Text('통계 데이터를 불러올 수 없습니다.'),
      );
    }

    final totalErrors = _statistics!['totalErrors'] as int;
    final visibleErrors = _statistics!['visibleErrors'] as int;
    final hiddenErrors = _statistics!['hiddenErrors'] as int;
    final recentErrors = _statistics!['recentErrors24h'] as int;
    final errorTypes = _statistics!['errorTypes'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 전체 통계 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 전체 통계',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('총 에러', totalErrors.toString(), Colors.red),
                      _buildStatCard('표시중', visibleErrors.toString(), Colors.blue),
                      _buildStatCard('숨김', hiddenErrors.toString(), Colors.grey),
                      _buildStatCard('24시간', recentErrors.toString(), Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 🔥 에러 유형별 통계
          const Text(
            '🔍 에러 유형별 발생 현황',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 10),
          
          Expanded(
            child: Card(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: errorTypes.length,
                itemBuilder: (context, index) {
                  final errorType = errorTypes[index] as Map<String, dynamic>;
                  final title = errorType['title'] as String;
                  final count = errorType['count'] as int;
                  final percentage = totalErrors > 0 ? (count / totalErrors * 100) : 0;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '$count회 (${percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getColorForIndex(index),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 🔥 새로고침 버튼
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadStatistics();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.cyan,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}

class ServerStatusCard extends StatelessWidget {
  final ServerStatus serverStatus;

  const ServerStatusCard({Key? key, required this.serverStatus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '메인 서버',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: serverStatus.isHealthy ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    serverStatus.isHealthy ? '정상' : '오류',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '응답 시간: ${serverStatus.responseTime}ms',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                Text(
                  '업타임: ${serverStatus.uptime.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecentAlertsWidget extends StatelessWidget {
  final List<ErrorAlert> errors;
  final GlobalKey<AnimatedListState> listKey;
  final Function(int) onErrorHide;  // 🔥 에러 숨기기 콜백 추가

  const RecentAlertsWidget({
    Key? key, 
    required this.errors,
    required this.listKey,
    required this.onErrorHide,  // 🔥 콜백 필수
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            '아직 에러가 없습니다.\n백그라운드에서 서버를 감시 중...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: errors.length,
        itemBuilder: (context, index) {
          final error = errors[index];
          return Dismissible(
            key: Key('error_${error.id}'),
            direction: DismissDirection.endToStart,  // 왼쪽으로만 스와이프
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 30,
              ),
            ),
            onDismissed: (direction) {
              onErrorHide(error.id);  // 🔥 에러 숨기기 호출
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${error.errorCode} 알림이 숨겨졌습니다'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: AlertListItem(
              title: error.title,
              time: error.timeAgo,
              severity: error.severity,
              errorCode: error.errorCode,
            ),
          );
        },
      ),
    );
  }
}

class AlertListItem extends StatelessWidget {
  final String title;
  final String time;
  final String severity;
  final String errorCode;

  const AlertListItem({
    Key? key,
    required this.title,
    required this.time,
    required this.severity,
    required this.errorCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    switch (severity) {
      case 'Error':
        severityColor = Colors.red;
        break;
      case 'Warning':
        severityColor = Colors.orange;
        break;
      case 'Info':
        severityColor = Colors.blue;
        break;
      default:
        severityColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          severity == 'Info' ? Icons.info : Icons.error,
          color: severityColor,
          size: 28,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('에러 코드: $errorCode'),
            Text(time),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: severityColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            severity,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
