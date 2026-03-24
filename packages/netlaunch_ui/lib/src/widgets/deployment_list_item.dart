import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:netlaunch_core/netlaunch_core.dart';
import 'package:netlaunch_ui/src/theme/app_colors.dart';
import 'status_badge.dart';

class DeploymentListItem extends StatelessWidget {
  final Deployment deployment;
  final VoidCallback? onTap;

  const DeploymentListItem({
    super.key,
    required this.deployment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGrayBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.language, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deployment.subdomain.isNotEmpty
                        ? deployment.subdomain
                        : 'Deployment',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deployment.url.isNotEmpty
                        ? deployment.url
                        : 'No URL',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: deployment.status),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(deployment.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
