import 'package:flutter/material.dart';
import '../models/server_status.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

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