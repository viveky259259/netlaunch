import 'package:flutter/material.dart';
import 'package:flutterkit/kit/kit.dart';
import '../models/deployment.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';
import '../widgets/stats_card.dart';
import '../widgets/log_entry_widget.dart';
import '../utils/url_launcher.dart';

class SiteDetailScreen extends StatelessWidget {
  final Deployment deployment;

  const SiteDetailScreen({super.key, required this.deployment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Site Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: UkContainer(
          size: UkContainerSize.large,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(status: deployment.status),
                        const Spacer(),
                        if (deployment.url.isNotEmpty)
                          UkButton(
                            label: 'Visit Site',
                            variant: UkButtonVariant.primary,
                            size: UkButtonSize.small,
                            icon: Icons.open_in_new,
                            onPressed: () => launchUrl(deployment.url),
                          ),
                        const SizedBox(width: 8),
                        UkButton(
                          label: 'Redeploy',
                          variant: UkButtonVariant.outline,
                          size: UkButtonSize.small,
                          icon: Icons.refresh,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Redeploy coming soon!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      deployment.subdomain.isNotEmpty ? deployment.subdomain : 'Deployment',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (deployment.url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        deployment.url,
                        style: const TextStyle(fontSize: 14, color: AppColors.teal),
                      ),
                    ],
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
              const SizedBox(height: 24),

              // Analytics
              UkGrid(
                gap: 16,
                children: [
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: const StatsCard(
                      title: 'Requests (24h)',
                      value: '--',
                      icon: Icons.bar_chart,
                    ),
                  ),
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: const StatsCard(
                      title: 'Avg Latency',
                      value: '--',
                      icon: Icons.speed,
                    ),
                  ),
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: const StatsCard(
                      title: 'Error Rate',
                      value: '--',
                      icon: Icons.error_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Chart Area
              Container(
                width: double.infinity,
                height: 200,
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
                      'Traffic Overview',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: CustomPaint(
                        painter: _TrafficChartPainter(),
                        size: const Size(double.infinity, double.infinity),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Site Settings
              UkAccordion(
                items: [
                  UkAccordionItem(
                    title: 'Custom Domains',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No custom domains configured.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        UkButton(
                          label: 'Add Domain',
                          variant: UkButtonVariant.outline,
                          size: UkButtonSize.small,
                          icon: Icons.add,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  UkAccordionItem(
                    title: 'Environment Variables',
                    content: const Text(
                      'No environment variables set.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  UkAccordionItem(
                    title: 'Deploy History',
                    content: const Text(
                      'Deploy history will appear here.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  UkAccordionItem(
                    title: 'Access Control',
                    content: const Text(
                      'Access control settings coming soon.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Runtime Logs
              Container(
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
                    Row(
                      children: [
                        const Text(
                          'Runtime Logs',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const Spacer(),
                        UkBadge('Live', variant: UkBadgeVariant.primary),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LogEntryWidget(
                            timestamp: '12:01:03',
                            level: 'info',
                            message: 'Deployment started',
                          ),
                          LogEntryWidget(
                            timestamp: '12:01:05',
                            level: 'info',
                            message: 'Extracting archive...',
                          ),
                          LogEntryWidget(
                            timestamp: '12:01:08',
                            level: 'info',
                            message: 'Uploading to CDN (3 files)',
                          ),
                          LogEntryWidget(
                            timestamp: '12:01:12',
                            level: 'info',
                            message: 'SSL certificate provisioned',
                          ),
                          LogEntryWidget(
                            timestamp: '12:01:14',
                            level: 'info',
                            message: 'Deployment complete',
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
  }
}

class _TrafficChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line chart
    final paint = Paint()
      ..color = AppColors.teal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.1, size.height * 0.5),
      Offset(size.width * 0.2, size.height * 0.55),
      Offset(size.width * 0.3, size.height * 0.35),
      Offset(size.width * 0.4, size.height * 0.45),
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.25),
      Offset(size.width * 0.8, size.height * 0.35),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width, size.height * 0.15),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(path, paint);

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.teal.withValues(alpha: 0.15), AppColors.teal.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
