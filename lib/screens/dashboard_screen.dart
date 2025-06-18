import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:vibration/vibration.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/error_alert.dart';
import '../models/server_status.dart';
import '../services/app_settings.dart';
import '../services/notification_service.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import '../widgets/server_status_card.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

// 🔥 백그라운드 서비스 채널
const platform = MethodChannel('background_service');

class DashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const DashboardScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Timer? _errorTimer;
  Timer? _statusTimer;
  List<ErrorAlert> _allErrors = [];
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
  String? _selectedType; // 🔥 유형 필터 추가
  
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
      final result = await platform.invokeMethod('getAllErrorsForStats');
      final List<dynamic> errorData = result as List<dynamic>;
      final List<ErrorAlert> newErrors = errorData.map((data) {
        final Map<String, dynamic> errorMap = Map<String, dynamic>.from(data);
        return ErrorAlert.fromMap(errorMap);
      }).toList();
      setState(() {
        _allErrors = newErrors;
        _errors = newErrors.where((e) => !e.isHidden && e.severity == "Error").take(20).toList();
      });
      
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
        return const StatisticsScreen();
      case 2:
        return SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
        );
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
            const SizedBox(height: 5),
            ServerStatusCard(serverStatus: _serverStatus),
            const SizedBox(height: 20),
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
                    '총 ${_allErrors.where((e) => !e.isHidden && e.severity == "Error").length}개',
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

  void _hideError(int errorId) async {
    try {
      await platform.invokeMethod('hideError', {'errorId': errorId});
      setState(() {
        _allErrors = _allErrors.map((e) =>
          e.id == errorId ? ErrorAlert(
            id: e.id,
            title: e.title,
            errorCode: e.errorCode,
            timestamp: e.timestamp,
            severity: e.severity,
            site: e.site,
            isHidden: true,
          ) : e
        ).toList();
        _errors.removeWhere((error) => error.id == errorId);
      });
      print('🙈 에러 숨김 처리 완료: ID=$errorId');
    } catch (e) {
      print('❌ 에러 숨김 실패: $e');
    }
  }
}

class RecentAlertsWidget extends StatelessWidget {
  final List<ErrorAlert> errors;
  final GlobalKey<AnimatedListState> listKey;
  final Function(int) onErrorHide;  // 🔥 에러 숨기기 콜백 추가

  const RecentAlertsWidget({
    super.key, 
    required this.errors,
    required this.listKey,
    required this.onErrorHide,  // 🔥 콜백 필수
  });

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
    super.key,
    required this.title,
    required this.time,
    required this.severity,
    required this.errorCode,
    required this.site,
  });

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