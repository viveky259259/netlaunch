import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:intl/intl.dart';
import 'package:netlaunch_core/netlaunch_core.dart';
import 'package:netlaunch_api/netlaunch_api.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';
import 'package:netlaunch_ui/netlaunch_ui.dart';
import '../utils/url_launcher.dart';
import '../widgets/analytics_section.dart';

class SiteDetailScreen extends StatefulWidget {
  final Deployment deployment;

  const SiteDetailScreen({super.key, required this.deployment});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  bool _isRedeploying = false;
  double _uploadProgress = 0.0;
  String? _redeployError;

  Future<void> _redeploy() async {
    final storageService = Provider.of<StorageService>(context, listen: false);

    // Pick ZIP file
    final result = await storageService.pickZipFile();
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;

    // Get API key from deployment or saved preferences
    String apiKey = widget.deployment.apiKey;
    if (apiKey.isEmpty) {
      final prefsService = UserPreferencesService(
        Provider.of<AuthProvider>(context, listen: false),
      );
      apiKey = await prefsService.getLastUsedApiKey() ?? '';
    }
    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No API key found. Please deploy from the dashboard first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String siteName = widget.deployment.subdomain;
    // Fallback: extract site name from URL (e.g. https://my-app.web.app/)
    if (siteName.isEmpty && widget.deployment.url.isNotEmpty) {
      final uri = Uri.tryParse(widget.deployment.url);
      if (uri != null && uri.host.endsWith('.web.app')) {
        siteName = uri.host.replaceAll('.web.app', '');
      }
    }
    if (siteName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot redeploy: no site name found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRedeploying = true;
      _uploadProgress = 0.0;
      _redeployError = null;
    });

    try {
      final uploadStream = await storageService.uploadZipFileWithProgressAsync(
        apiKey,
        file.bytes!,
        file.name,
        siteName,
      );

      uploadStream.listen(
        (snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isRedeploying = false;
              _uploadProgress = 0.0;
              _redeployError = error.toString();
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isRedeploying = false;
              _uploadProgress = 0.0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Redeployment started! Your site will update shortly.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRedeploying = false;
          _uploadProgress = 0.0;
          _redeployError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deployment = widget.deployment;

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
                          label: _isRedeploying ? 'Uploading...' : 'Redeploy',
                          variant: UkButtonVariant.outline,
                          size: UkButtonSize.small,
                          icon: _isRedeploying ? Icons.hourglass_top : Icons.refresh,
                          onPressed: _isRedeploying ? null : _redeploy,
                        ),
                      ],
                    ),
                    // Redeploy progress
                    if (_isRedeploying) ...[
                      const SizedBox(height: 16),
                      UkProgress(
                        value: _uploadProgress,
                        variant: UkProgressVariant.primary,
                        size: UkProgressSize.large,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    // Redeploy error
                    if (_redeployError != null) ...[
                      const SizedBox(height: 12),
                      UkAlert(
                        message: _redeployError!,
                        type: UkAlertType.danger,
                        dismissible: true,
                        onDismissed: () => setState(() => _redeployError = null),
                      ),
                    ],
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

              // Deployment Info
              UkGrid(
                gap: 16,
                children: [
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: StatsCard(
                      title: 'Status',
                      value: deployment.status.isNotEmpty
                          ? deployment.status[0].toUpperCase() + deployment.status.substring(1)
                          : '--',
                      icon: Icons.info_outline,
                      iconColor: deployment.status == 'success'
                          ? AppColors.teal
                          : deployment.status == 'failed'
                              ? AppColors.statusFailed
                              : null,
                    ),
                  ),
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: StatsCard(
                      title: 'Deployed',
                      value: DateFormat('MMM d, y').format(deployment.createdAt),
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  UkCol(
                    xs: 12,
                    md: 4,
                    child: StatsCard(
                      title: 'Subdomain',
                      value: deployment.subdomain.isNotEmpty ? deployment.subdomain : '--',
                      icon: Icons.language,
                      iconColor: AppColors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Analytics (successful deployments only)
              if (deployment.status == 'success') ...[
                AnalyticsSection(deploymentId: deployment.id),
                const SizedBox(height: 24),
              ],

              // Deployment Details
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
                    const Text(
                      'Deployment Details',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    _detailRow('Deployment ID', deployment.id),
                    if (deployment.filePath != null)
                      _detailRow('File Path', deployment.filePath!),
                    _detailRow('Created', DateFormat('MMM d, y · h:mm a').format(deployment.createdAt)),
                    _detailRow('Last Updated', DateFormat('MMM d, y · h:mm a').format(deployment.updatedAt)),
                    if (deployment.url.isNotEmpty)
                      _detailRow('URL', deployment.url),
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

              // Deployment Log
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
                    const Text(
                      'Deployment Log',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildLogEntries(),
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

  List<LogEntryWidget> _buildLogEntries() {
    final deployment = widget.deployment;
    final timeFormat = DateFormat('HH:mm:ss');
    final entries = <LogEntryWidget>[];

    entries.add(LogEntryWidget(
      timestamp: timeFormat.format(deployment.createdAt),
      level: 'info',
      message: 'Deployment created for ${deployment.subdomain.isNotEmpty ? deployment.subdomain : deployment.id}',
    ));

    if (deployment.filePath != null) {
      entries.add(LogEntryWidget(
        timestamp: timeFormat.format(deployment.createdAt),
        level: 'info',
        message: 'File uploaded: ${deployment.filePath!.split('/').last}',
      ));
    }

    if (deployment.status == 'deploying' || deployment.status == 'success' || deployment.status == 'failed') {
      entries.add(LogEntryWidget(
        timestamp: timeFormat.format(deployment.updatedAt),
        level: 'info',
        message: 'Deployment processing started',
      ));
    }

    if (deployment.status == 'success') {
      entries.add(LogEntryWidget(
        timestamp: timeFormat.format(deployment.updatedAt),
        level: 'info',
        message: 'Deployment complete — live at ${deployment.url}',
      ));
    } else if (deployment.status == 'failed') {
      entries.add(LogEntryWidget(
        timestamp: timeFormat.format(deployment.updatedAt),
        level: 'error',
        message: deployment.error ?? 'Deployment failed',
      ));
    } else if (deployment.status == 'pending') {
      entries.add(LogEntryWidget(
        timestamp: timeFormat.format(deployment.updatedAt),
        level: 'warn',
        message: 'Waiting to be processed...',
      ));
    }

    return entries;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
