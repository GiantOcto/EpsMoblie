import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../services/app_settings.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const SettingsScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
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
} 