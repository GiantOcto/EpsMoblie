import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

// 🔥 분리된 파일들 import
import 'models/error_alert.dart';
import 'models/server_status.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';
import 'themes/app_colors.dart';
import 'themes/app_text_styles.dart';
import 'widgets/server_status_card.dart';
import 'screens/dashboard_screen.dart';

// 🔥 백그라운드 서비스 채널
const platform = MethodChannel('background_service');

// 전역 알림 플러그인
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

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
