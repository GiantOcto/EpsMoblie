import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';  // 🔥 설정 저장용 추가

// 🔥 백그라운드 서비스 채널
const platform = MethodChannel('background_service');

// 전역 알림 플러그인
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

// 🔥 설정 관리 클래스
class AppSettings {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;
  
  static bool get soundEnabled => _soundEnabled;
  static bool get vibrationEnabled => _vibrationEnabled;
  
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
    print('🔧 설정 로드: 사운드=$_soundEnabled, 진동=$_vibrationEnabled');
  }
  
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
    print('🔊 사운드 설정: $enabled');
  }
  
  static Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
    print('📳 진동 설정: $enabled');
  }
}

// 🎨 디자인 시스템
class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);
  
  // 그라데이션
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 설정 로드
  await AppSettings.loadSettings();
  
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
      playSound: AppSettings.soundEnabled,
      enableVibration: AppSettings.vibrationEnabled,
      vibrationPattern: AppSettings.vibrationEnabled 
          ? Int64List.fromList([0, 500, 200, 300]) 
          : null,
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
  final int id;
  final String title;
  final String errorCode;
  final DateTime timestamp;
  final String severity;
  final String site;  // 🔥 현장명 추가

  ErrorAlert({
    required this.id,
    required this.title,
    required this.errorCode,
    required this.timestamp,
    required this.severity,
    required this.site,  // 🔥 현장명 필수
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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: AppTextStyles.heading3.copyWith(color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          elevation: 20,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.caption,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          titleTextStyle: AppTextStyles.heading3.copyWith(color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          elevation: 20,
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: AppColors.secondary,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.caption,
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

  // 🔥 필터 상태
  String _selectedSite = '전체';
  DateTime? _selectedDate;
  
  final List<String> _sites = ['전체', '서울본사', '부산지점', '대구지점', '인천지점', '광주지점', '대전지점', '울산지점', '제주지점'];

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
    _errorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
          site: errorMap['site'] as String,  // 🔥 현장명 추가
        );
      }).toList();
      
      // 🔥 새로운 에러 확인 및 UI 업데이트 로직 개선
      final oldCount = _errors.length;
      final newCount = newErrors.length;

      // 🔥 에러 목록이 변경되었는지 확인
      bool hasChanges = false;
      
      if (newCount != oldCount) {
        hasChanges = true;
      } else if (newCount > 0 && oldCount > 0) {
        // 🔥 개수는 같지만 내용이 다른지 확인 (최신 에러 ID 비교)
        final newLatestId = newErrors.isNotEmpty ? newErrors.first.id : 0;
        final oldLatestId = _errors.isNotEmpty ? _errors.first.id : 0;
        if (newLatestId != oldLatestId) {
          hasChanges = true;
        }
      }

      if (hasChanges) {
        setState(() {
          _errors = newErrors;
        });
        
        print('📱 DB에서 ${newErrors.length}개 에러 로드됨 (이전: $oldCount개)');
        
        // 🔥 새 에러가 추가되었을 때만 사운드/진동
        if (newCount > oldCount) {
          print('🔔 새로운 에러 ${newCount - oldCount}개 감지됨!');
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
    if (!AppSettings.soundEnabled) return;  // 🔥 설정 확인
    
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('사운드 재생 실패: $e');
    }
  }

  void _triggerVibration() async {
    if (!AppSettings.vibrationEnabled) return;  // 🔥 설정 확인
    
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 🔥 앱이 포그라운드로 돌아올 때 즉시 새로고침
    if (state == AppLifecycleState.resumed) {
      print('📱 앱이 포그라운드로 돌아옴 - 즉시 새로고침');
      _loadErrorsFromDatabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: AppBar(
            title: Text(
              _getAppBarTitle(),
              style: AppTextStyles.heading3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: widget.isDarkMode,
                      onChanged: (value) => widget.onThemeToggle(),
                      activeColor: AppColors.secondary,
                      activeTrackColor: AppColors.secondary.withOpacity(0.3),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _getBodyWidget(),  // 🔥 동적 본문
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,  // 🔥 3개 탭 지원
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: '통계',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'EPS Moblie';
      case 1:
        return '에러 통계';
      case 2:
        return '설정';
      default:
        return 'EPS Moblie';
    }
  }

  Widget _getBodyWidget() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildStatistics();
      case 2:
        return _buildSettings();  // 🔥 설정 페이지
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF8F9FA),
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117)
                : Colors.white,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ServerStatusCard(serverStatus: _serverStatus),
            const SizedBox(height: 30),
            Row(
              children: [
                Text(
                  '최근 알림',
                  style: AppTextStyles.heading2.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    '총 ${_errors.length}개',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RecentAlertsWidget(
              errors: _errors,
              listKey: _listKey,
              onErrorHide: _hideError,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return const StatisticsPage();
  }

  Widget _buildSettings() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF8F9FA),
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117)
                : Colors.white,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            
            // 🔊 사운드 설정 카드
            _buildSettingCard(
              icon: Icons.volume_up,
              title: '알림 사운드',
              description: AppSettings.soundEnabled 
                  ? '에러 발생시 알림음이 재생됩니다' 
                  : '에러 발생시 무음으로 알림이 표시됩니다',
              value: AppSettings.soundEnabled,
              color: AppColors.info,
              onChanged: (value) async {
                await AppSettings.setSoundEnabled(value);
                setState(() {});
                if (value) {
                  SystemSound.play(SystemSoundType.alert);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // 📳 진동 설정 카드
            _buildSettingCard(
              icon: Icons.vibration,
              title: '진동 알림',
              description: AppSettings.vibrationEnabled 
                  ? '에러 발생시 진동으로 알림합니다' 
                  : '에러 발생시 진동없이 조용히 알림합니다',
              value: AppSettings.vibrationEnabled,
              color: AppColors.warning,
              onChanged: (value) async {
                await AppSettings.setVibrationEnabled(value);
                setState(() {});
                if (value) {
                  try {
                    bool? hasVibrator = await Vibration.hasVibrator();
                    if (hasVibrator == true) {
                      await Vibration.vibrate(pattern: [0, 300, 100, 200]);
                    } else {
                      HapticFeedback.mediumImpact();
                    }
                  } catch (e) {
                    HapticFeedback.lightImpact();
                  }
                }
              },
            ),
            
            const Spacer(),
            
            // 🔥 테스트 버튼
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  NotificationService.showErrorNotification(
                    title: '테스트 에러',
                    errorCode: 'TEST_001',
                    body: '설정 테스트용 알림입니다',
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text('테스트 알림이 전송되었습니다!'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.notification_add, color: Colors.white),
                label: Text(
                  '알림 테스트',
                  style: AppTextStyles.body1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFAFAFA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: color,
                    activeTrackColor: color.withOpacity(0.3),
                    inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey[400],
                    inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: AppTextStyles.body2.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
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

// 🔥 고급 통계 페이지 (필터링 지원)
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ErrorAlert> _allErrors = [];
  bool _isLoading = true;
  
  // 🔥 필터 상태
  String _selectedSite = '전체';
  DateTime? _selectedDate;
  
  final List<String> _sites = ['전체', '서울본사', '부산지점', '대구지점', '인천지점', '광주지점', '대전지점', '울산지점', '제주지점'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllErrors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAllErrors() async {
    try {
      final result = await platform.invokeMethod('getAllErrorsForStats');  // 🔥 통계용 메소드 사용
      final List<dynamic> errorData = result as List<dynamic>;
      
      setState(() {
        _allErrors = errorData.map((data) {
          final Map<String, dynamic> errorMap = Map<String, dynamic>.from(data);
          return ErrorAlert(
            id: errorMap['id'] as int,
            title: errorMap['title'] as String,
            errorCode: errorMap['errorCode'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(errorMap['timestamp'] as int),
            severity: errorMap['severity'] as String,
            site: errorMap['site'] as String,
          );
        }).toList();
        _isLoading = false;
      });
      
      print('📊 통계용 전체 에러 ${_allErrors.length}개 로드됨');
    } catch (e) {
      print('❌ 통계 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ErrorAlert> get _filteredErrors {
    return _allErrors.where((error) {
      // 현장 필터
      if (_selectedSite != '전체' && error.site != _selectedSite) return false;
      
      // 날짜 필터
      if (_selectedDate != null) {
        final errorDate = DateTime(error.timestamp.year, error.timestamp.month, error.timestamp.day);
        final selectedDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        if (!errorDate.isAtSameMomentAs(selectedDate)) return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 🔥 필터 영역
        _buildFilterSection(),
        
        // 🔥 탭 바
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '현장별', icon: Icon(Icons.location_on)),
            Tab(text: '유형별', icon: Icon(Icons.category)),
            Tab(text: '일별', icon: Icon(Icons.calendar_today)),
          ],
        ),
        
        // 🔥 탭 내용
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSiteStatistics(),
              _buildTypeStatistics(),
              _buildDateStatistics(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // 현장 선택
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('현장: '),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSite,
                    isExpanded: true,
                    alignment: Alignment.center,  // 🔥 중앙정렬
                    items: _sites.map((site) => DropdownMenuItem(
                      value: site,
                      alignment: Alignment.center,  // 🔥 드롭다운 아이템도 중앙정렬
                      child: Text(site),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedSite = value!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 날짜 선택
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.green),
                const SizedBox(width: 8),
                const Text('날짜: '),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: Text(
                      _selectedDate != null 
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : '전체 기간',
                      textAlign: TextAlign.center,  // 🔥 중앙정렬
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    onPressed: () => setState(() => _selectedDate = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            
            // 필터 결과 요약
            Text(
              '필터 결과: ${_filteredErrors.length}개 / 전체 ${_allErrors.length}개',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteStatistics() {
    final siteStats = <String, int>{};
    for (final error in _filteredErrors) {
      siteStats[error.site] = (siteStats[error.site] ?? 0) + 1;
    }
    
    final sortedSites = siteStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedSites.isEmpty) {
      return _buildEmptyState('현장별 데이터가 없습니다');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF8F9FA),
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117)
                : Colors.white,
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedSites.length,
        itemBuilder: (context, index) {
          final entry = sortedSites[index];
          final percentage = _filteredErrors.isNotEmpty ? (entry.value / _filteredErrors.length * 100) : 0;
          final maxValue = sortedSites.isNotEmpty ? sortedSites.first.value : 1;
          final normalizedValue = entry.value / maxValue;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF2A2A2A) 
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1F1F1F) 
                      : const Color(0xFFFAFAFA),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: AppTextStyles.heading3.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value}건 (${percentage.toStringAsFixed(1)}%)',
                              style: AppTextStyles.body2.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[400] 
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7 * normalizedValue,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeStatistics() {
    final typeStats = <String, int>{};
    for (final error in _filteredErrors) {
      typeStats[error.title] = (typeStats[error.title] ?? 0) + 1;
    }
    
    final sortedTypes = typeStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedTypes.isEmpty) {
      return _buildEmptyState('유형별 데이터가 없습니다');
    }

    final errorTypeColors = [
      [AppColors.error, AppColors.error.withOpacity(0.7)],
      [AppColors.warning, Colors.orange.withOpacity(0.7)],
      [AppColors.info, AppColors.info.withOpacity(0.7)],
      [AppColors.success, AppColors.success.withOpacity(0.7)],
      [Colors.purple, Colors.purple.withOpacity(0.7)],
      [Colors.teal, Colors.teal.withOpacity(0.7)],
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF8F9FA),
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117)
                : Colors.white,
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedTypes.length,
        itemBuilder: (context, index) {
          final entry = sortedTypes[index];
          final percentage = _filteredErrors.isNotEmpty ? (entry.value / _filteredErrors.length * 100) : 0;
          final maxValue = sortedTypes.isNotEmpty ? sortedTypes.first.value : 1;
          final normalizedValue = entry.value / maxValue;
          final colorPair = errorTypeColors[index % errorTypeColors.length];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF2A2A2A) 
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1F1F1F) 
                      : const Color(0xFFFAFAFA),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorPair[0].withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colorPair,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colorPair[0].withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.error_outline, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: AppTextStyles.body1.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value}건 (${percentage.toStringAsFixed(1)}%)',
                              style: AppTextStyles.body2.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[400] 
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colorPair,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7 * normalizedValue,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colorPair,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: colorPair[0].withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateStatistics() {
    final dateStats = <String, int>{};
    for (final error in _filteredErrors) {
      final dateKey = '${error.timestamp.year}-${error.timestamp.month.toString().padLeft(2, '0')}-${error.timestamp.day.toString().padLeft(2, '0')}';
      dateStats[dateKey] = (dateStats[dateKey] ?? 0) + 1;
    }
    
    final sortedDates = dateStats.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // 최신 날짜부터

    if (sortedDates.isEmpty) {
      return _buildEmptyState('일별 데이터가 없습니다');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF8F9FA),
            Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0D1117)
                : Colors.white,
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final entry = sortedDates[index];
          final percentage = _filteredErrors.isNotEmpty ? (entry.value / _filteredErrors.length * 100) : 0;
          final maxValue = sortedDates.isNotEmpty ? sortedDates.first.value : 1;
          final normalizedValue = entry.value / maxValue;
          
          // 날짜별로 다른 색상 그라데이션
          final hue = (index * 60) % 360;
          final color = HSVColor.fromAHSV(1.0, hue.toDouble(), 0.7, 0.8).toColor();
          final colorPair = [color, color.withOpacity(0.7)];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF2A2A2A) 
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1F1F1F) 
                      : const Color(0xFFFAFAFA),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colorPair,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: AppTextStyles.heading3.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value}건 (${percentage.toStringAsFixed(1)}%)',
                              style: AppTextStyles.body2.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[400] 
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colorPair,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7 * normalizedValue,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: colorPair,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
    );
  }
}

class ServerStatusCard extends StatelessWidget {
  final ServerStatus serverStatus;

  const ServerStatusCard({Key? key, required this.serverStatus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFAFAFA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.successGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_done,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '메인 서버',
                        style: AppTextStyles.heading3.copyWith(
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'server.eps.co.kr',
                        style: AppTextStyles.body2.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: serverStatus.isHealthy 
                        ? AppColors.successGradient 
                        : AppColors.errorGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (serverStatus.isHealthy ? AppColors.success : AppColors.error)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        serverStatus.isHealthy ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        serverStatus.isHealthy ? '정상' : '오류',
                        style: AppTextStyles.body2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      '응답 시간',
                      '${serverStatus.responseTime}ms',
                      Icons.speed,
                      AppColors.info,
                      isDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildMetric(
                      '업타임',
                      '${serverStatus.uptime.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      AppColors.success,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.heading3.copyWith(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
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
              site: error.site,  // 🔥 현장명 추가
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
  final String site;

  const AlertListItem({
    Key? key,
    required this.title,
    required this.time,
    required this.severity,
    required this.errorCode,
    required this.site,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color severityColor;
    IconData severityIcon;
    LinearGradient severityGradient;
    
    switch (severity) {
      case 'Error':
        severityColor = AppColors.error;
        severityIcon = Icons.error;
        severityGradient = AppColors.errorGradient;
        break;
      case 'Warning':
        severityColor = AppColors.warning;
        severityIcon = Icons.warning;
        severityGradient = LinearGradient(
          colors: [AppColors.warning, Colors.orange[300]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case 'Info':
        severityColor = AppColors.info;
        severityIcon = Icons.info;
        severityGradient = AppColors.primaryGradient;
        break;
      default:
        severityColor = AppColors.info;
        severityIcon = Icons.info;
        severityGradient = AppColors.primaryGradient;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1F1F1F) : const Color(0xFFFAFAFA),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: severityColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: severityGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: severityColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                severityIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        site,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        errorCode,
                        style: AppTextStyles.body2.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: AppTextStyles.body2.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: severityGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: severityColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                severity,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
