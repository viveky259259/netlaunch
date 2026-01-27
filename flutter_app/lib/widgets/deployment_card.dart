import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'deploying':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(deployment.status),
                  color: _getStatusColor(deployment.status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deployment.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(deployment.status),
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (deployment.url.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deployment.url,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: deployment.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  launchUrl(deployment.url);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Browser'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Subdomain: ${deployment.subdomain}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${dateFormat.format(deployment.createdAt)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            if (deployment.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Error: ${deployment.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

