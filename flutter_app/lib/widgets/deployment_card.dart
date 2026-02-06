import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutterkit/kit/kit.dart';
import '../models/deployment.dart';
import '../utils/url_launcher.dart';

class DeploymentCard extends StatelessWidget {
  final Deployment deployment;
  final VoidCallback? onDelete;

  const DeploymentCard({
    super.key,
    required this.deployment,
    this.onDelete,
  });

  UkBadgeVariant _getBadgeVariant(String status) {
    switch (status) {
      case 'success':
        return UkBadgeVariant.primary;
      case 'failed':
        return UkBadgeVariant.tertiary;
      case 'deploying':
        return UkBadgeVariant.secondary;
      case 'pending':
        return UkBadgeVariant.neutral;
      default:
        return UkBadgeVariant.neutral;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'deploying':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: UkCard(
        header: Row(
          children: [
            Icon(
              _getStatusIcon(deployment.status),
              size: 20,
              color: deployment.status == 'success'
                  ? Colors.green
                  : deployment.status == 'failed'
                      ? cs.error
                      : cs.primary,
            ),
            const SizedBox(width: 8),
            UkBadge(
              deployment.status.toUpperCase(),
              variant: _getBadgeVariant(deployment.status),
            ),
            const Spacer(),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete deployment',
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deployment.url.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deployment.url,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: cs.primary),
                    tooltip: 'Copy URL',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: deployment.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('URL copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              UkButton(
                label: 'Open in Browser',
                variant: UkButtonVariant.outline,
                size: UkButtonSize.small,
                icon: Icons.open_in_new,
                onPressed: () {
                  launchUrl(deployment.url);
                },
              ),
            ],
            const SizedBox(height: 12),
            const UkDivider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.language, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  deployment.subdomain,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(deployment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            if (deployment.error != null) ...[
              const SizedBox(height: 12),
              UkAlert(
                message: deployment.error!,
                type: UkAlertType.danger,
                dismissible: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
