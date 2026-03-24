import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';
import 'package:netlaunch_api/netlaunch_api.dart';
import 'package:netlaunch_core/netlaunch_core.dart';
import 'package:netlaunch_ui/netlaunch_ui.dart';
import 'new_deployment_screen.dart';
import 'site_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<Deployment>>? _deploymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadDeployments();
  }

  void _loadDeployments() {
    final functionsService = Provider.of<FunctionsService>(context, listen: false);
    setState(() {
      _deploymentsFuture = functionsService.listUserDeployments();
    });
  }

  void _navigateToNewDeployment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewDeploymentScreen()),
    );
    if (result == true) _loadDeployments();
  }

  void _navigateToSiteDetail(Deployment deployment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SiteDetailScreen(deployment: deployment)),
    );
    _loadDeployments();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: AppColors.teal, size: 24),
            const SizedBox(width: 8),
            const Text(
              'NetLaunch',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 16),
            Text(
              'Console / Dashboard',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _loadDeployments,
          ),
          if (user != null)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.teal,
                child: user.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user.photoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            user.email?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      )
                    : Text(
                        user.email?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
              ),
              onSelected: (value) {
                if (value == 'settings') _navigateToSettings();
                if (value == 'signout') _signOut();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(user.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDeployments(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: UkContainer(
            size: UkContainerSize.large,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Row
                FutureBuilder<List<Deployment>>(
                  future: _deploymentsFuture,
                  builder: (context, snapshot) {
                    final deployments = snapshot.data ?? [];
                    final active = deployments.where((d) => d.status == 'success').length;
                    final total = deployments.length;
                    final successRate = total > 0 ? (active / total * 100).toStringAsFixed(1) : '0.0';
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    return UkGrid(
                      gap: 16,
                      children: [
                        UkCol(
                          xs: 12,
                          md: 4,
                          child: StatsCard(
                            title: 'Active Deployments',
                            value: isLoading ? '...' : '$active',
                            icon: Icons.cloud_done_outlined,
                            iconColor: AppColors.teal,
                          ),
                        ),
                        UkCol(
                          xs: 12,
                          md: 4,
                          child: StatsCard(
                            title: 'Total Deployments',
                            value: isLoading ? '...' : '$total',
                            icon: Icons.layers_outlined,
                          ),
                        ),
                        UkCol(
                          xs: 12,
                          md: 4,
                          child: StatsCard(
                            title: 'Success Rate',
                            value: isLoading ? '...' : '$successRate%',
                            icon: Icons.trending_up,
                            iconColor: AppColors.teal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // CTA Banner
                CtaBanner(onPressed: _navigateToNewDeployment),
                const SizedBox(height: 32),

                // Recent Deployments
                const Text(
                  'Recent Deployments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                FutureBuilder<List<Deployment>>(
                  future: _deploymentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: List.generate(
                          3,
                          (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: UkSkeleton(
                              height: 80,
                              width: double.infinity,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.statusFailed),
                            const SizedBox(height: 12),
                            UkAlert(
                              message: 'Error loading deployments. Make sure you have generated an API key first.',
                              type: UkAlertType.danger,
                              dismissible: false,
                            ),
                            const SizedBox(height: 12),
                            UkButton(
                              label: 'Retry',
                              variant: UkButtonVariant.outline,
                              icon: Icons.refresh,
                              onPressed: _loadDeployments,
                            ),
                          ],
                        ),
                      );
                    }

                    final deployments = snapshot.data ?? [];

                    if (deployments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.web_outlined, size: 56, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              const Text(
                                'No deployments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Deploy your first site to get started.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              UkButton(
                                label: 'Deploy Now',
                                variant: UkButtonVariant.primary,
                                icon: Icons.add,
                                onPressed: _navigateToNewDeployment,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: deployments
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DeploymentListItem(
                                  deployment: d,
                                  onTap: () => _navigateToSiteDetail(d),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToNewDeployment,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Deploy'),
      ),
    );
  }
}
