import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: config.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig() {
    switch (status.toLowerCase()) {
      case 'success':
      case 'live':
        return _StatusConfig(
          label: 'Live',
          dot: AppColors.statusLive,
          text: AppColors.statusLive,
          bg: AppColors.tealLight,
        );
      case 'deploying':
      case 'building':
      case 'pending':
        return _StatusConfig(
          label: 'Building',
          dot: AppColors.statusBuilding,
          text: AppColors.statusBuilding,
          bg: const Color(0xFFFEF3C7),
        );
      case 'failed':
        return _StatusConfig(
          label: 'Failed',
          dot: AppColors.statusFailed,
          text: AppColors.statusFailed,
          bg: const Color(0xFFFEE2E2),
        );
      default:
        return _StatusConfig(
          label: status,
          dot: AppColors.textSecondary,
          text: AppColors.textSecondary,
          bg: const Color(0xFFF3F4F6),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color dot;
  final Color text;
  final Color bg;

  const _StatusConfig({
    required this.label,
    required this.dot,
    required this.text,
    required this.bg,
  });
}
