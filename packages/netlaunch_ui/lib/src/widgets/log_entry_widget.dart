import 'package:flutter/material.dart';
import 'package:netlaunch_ui/src/theme/app_colors.dart';

class LogEntryWidget extends StatelessWidget {
  final String timestamp;
  final String level;
  final String message;

  const LogEntryWidget({
    super.key,
    required this.timestamp,
    required this.level,
    required this.message,
  });

  Color get _levelColor {
    switch (level.toLowerCase()) {
      case 'info':
        return AppColors.teal;
      case 'warn':
      case 'warning':
        return AppColors.statusBuilding;
      case 'error':
        return AppColors.statusFailed;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timestamp,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _levelColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _levelColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
