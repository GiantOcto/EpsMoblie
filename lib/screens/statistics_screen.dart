import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import '../models/error_alert.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

// 🔥 백그라운드 서비스 채널
const platform = MethodChannel('background_service');

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ErrorAlert> _allErrors = [];
  bool _isLoading = true;
  
  // 🔥 필터 상태
  String _selectedSite = '전체';
  DateTime? _selectedDate;
  String? _selectedType; // 🔥 유형 필터 추가
  
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
            timestamp: DateTime.fromMillisecondsSinceEpoch(errorMap['timestamp'] as int, isUtc: true).toLocal(),
            severity: errorMap['severity'] as String,
            site: errorMap['site'] as String,
            isHidden: errorMap['isHidden'] == 1 || errorMap['isHidden'] == true || errorMap['isHidden'] == 'true',
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
      // 🔥 유형 필터
      if (_selectedType != null && _selectedType!.isNotEmpty && error.title != _selectedType) return false;
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
            // 🔥 '전체 보기' 버튼 (필터 적용 시만 노출)
            if (_selectedSite != '전체' || _selectedDate != null || (_selectedType != null && _selectedType!.isNotEmpty))
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _selectedSite = '전체';
                    _selectedDate = null;
                    _selectedType = null;
                  }),
                  icon: const Icon(Icons.list),
                  label: const Text('전체 보기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedSites.length,
      itemBuilder: (context, index) {
        final entry = sortedSites[index];
        final percentage = _filteredErrors.isNotEmpty ? (entry.value / _filteredErrors.length * 100) : 0;
        final maxValue = sortedSites.isNotEmpty ? sortedSites.first.value : 1;
        final normalizedValue = entry.value / maxValue;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedSite = entry.key;
            });
          },
          child: Container(
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
          ),
        );
      },
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
    // 겹치지 않는 색상 자동 생성 (HSV 색상환 등분)
    final int sectionCount = sortedTypes.length;
    final List<Color> pieColors = List.generate(
      sectionCount,
      (i) => HSVColor.fromAHSV(1.0, (i * 360 / sectionCount) % 360, 0.7, 0.9).toColor(),
    );
    final total = sortedTypes.fold<int>(0, (sum, e) => sum + e.value);
    List<PieChartSectionData> pieSections = [];
    for (int i = 0; i < sortedTypes.length; i++) {
      final entry = sortedTypes[i];
      final color = pieColors[i];
      final percent = total > 0 ? (entry.value / total * 100) : 0;
      pieSections.add(
        PieChartSectionData(
          color: color,
          value: entry.value.toDouble(),
          title: '', // 퍼센트 표시 제거
          radius: 60,
          titleStyle: AppTextStyles.body2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const SizedBox(height: 24),
        SizedBox(
          height: 330, // 파이차트 전체 크기 더 키움
          child: PieChart(
            PieChartData(
              sections: pieSections,
              centerSpaceRadius: 60, // 도넛 느낌 유지, 외곽 원 더 큼
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(enabled: true),
            ),
          ),
        ),
        const SizedBox(height: 32), // 차트와 범례 간격 넉넉히
        // 범례
        Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (int i = 0; i < sortedTypes.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: pieColors[i],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final entry = sortedTypes[i];
                        final percent = total > 0 ? (entry.value / total * 100) : 0;
                        return Text(
                          '${entry.key} (${entry.value}건, ${percent.toStringAsFixed(1)}%)',
                          style: AppTextStyles.body2.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 기존 리스트(선택적, 필요시 주석 해제)
        // ListView.builder 등 추가 가능
      ],
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
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime.parse(entry.key);
              });
            },
            child: Container(
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