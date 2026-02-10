import 'package:flutter/material.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:intl/intl.dart';
import '../models/deployment_analytics.dart';
import '../services/functions_service.dart';
import '../theme/app_colors.dart';
import 'stats_card.dart';

class AnalyticsSection extends StatefulWidget {
  final String deploymentId;

  const AnalyticsSection({super.key, required this.deploymentId});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  final FunctionsService _functions = FunctionsService();
  DeploymentAnalytics? _analytics;
  bool _loading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analytics = await _functions.getDeploymentAnalytics(
        widget.deploymentId,
        days: _days,
      );
      if (mounted) setState(() => _analytics = analytics);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setDays(int days) {
    if (days == _days) return;
    _days = days;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with time range toggles
        Row(
          children: [
            const Text(
              'Analytics',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const Spacer(),
            _RangeToggle(
              selected: _days,
              onChanged: _setDays,
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_loading) _buildLoading(),
        if (_error != null && !_loading) _buildError(),
        if (_analytics != null && !_loading) ...[
          _buildStatsCards(_analytics!),
          const SizedBox(height: 20),
          _buildBarChart(_analytics!),
          const SizedBox(height: 20),
          _buildTopPages(_analytics!),
        ],
      ],
    );
  }

  Widget _buildLoading() {
    return UkGrid(
      gap: 16,
      children: List.generate(
        3,
        (_) => UkCol(
          xs: 12,
          md: 4,
          child: UkSkeleton(height: 100, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        UkAlert(
          message: _error!.replaceFirst('Exception: ', ''),
          type: UkAlertType.danger,
          dismissible: false,
        ),
        const SizedBox(height: 8),
        UkButton(
          label: 'Retry',
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildStatsCards(DeploymentAnalytics a) {
    final formatter = NumberFormat.compact();
    return UkGrid(
      gap: 16,
      children: [
        UkCol(
          xs: 12,
          md: 4,
          child: StatsCard(
            title: 'Total Views',
            value: formatter.format(a.totalViews),
            icon: Icons.visibility_outlined,
            iconColor: AppColors.teal,
          ),
        ),
        UkCol(
          xs: 12,
          md: 4,
          child: StatsCard(
            title: 'Last ${a.periodDays}d',
            value: formatter.format(a.periodViews),
            icon: Icons.trending_up,
            iconColor: AppColors.statusBuilding,
          ),
        ),
        UkCol(
          xs: 12,
          md: 4,
          child: StatsCard(
            title: 'Top Device',
            value: a.topDevice,
            icon: Icons.devices,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(DeploymentAnalytics a) {
    final data = a.dailyData;
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: Text(
            'No view data yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final maxViews = data.map((d) => d.views).reduce((a, b) => a > b ? a : b);
    const chartHeight = 160.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Views',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight + 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < data.length; i++) ...[
                  Expanded(
                    child: Tooltip(
                      message: '${data[i].date}: ${data[i].views} views',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: maxViews > 0
                                ? (data[i].views / maxViews) * chartHeight
                                : 2,
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Show label for every ~7th bar or first/last
                          if (i == 0 ||
                              i == data.length - 1 ||
                              (data.length > 14 && i % 7 == 0) ||
                              (data.length <= 14 && i % 2 == 0))
                            Text(
                              data[i].date.substring(5), // MM-DD
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else
                            const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (i < data.length - 1) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPages(DeploymentAnalytics a) {
    if (a.topPages.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Pages',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < a.topPages.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.topPages[i].path,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    NumberFormat.compact().format(a.topPages[i].views),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _RangeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(7, '7d'),
          _chip(30, '30d'),
        ],
      ),
    );
  }

  Widget _chip(int days, String label) {
    final isActive = selected == days;
    return GestureDetector(
      onTap: () => onChanged(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
