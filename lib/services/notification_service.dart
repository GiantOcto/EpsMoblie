import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import '../services/app_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

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