import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterkit/kit/kit.dart';
import '../services/functions_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefsService = UserPreferencesService();
  String? _lastApiKey;
  bool _isLoadingKey = true;
  bool _isGeneratingKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await _prefsService.getLastUsedApiKey();
    if (mounted) {
      setState(() {
        _lastApiKey = key;
        _isLoadingKey = false;
      });
    }
  }

  Future<void> _generateApiKey() async {
    setState(() => _isGeneratingKey = true);

    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final apiKey = await functionsService.generateApiKey();
      await _prefsService.saveLastUsedApiKey(apiKey);
      if (mounted) {
        setState(() => _lastApiKey = apiKey);
        await Clipboard.setData(ClipboardData(text: apiKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New API key generated and copied!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: UkContainer(
          size: UkContainerSize.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              const Text(
                'Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.darkNavy,
                          child: user?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.photoURL!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 20),
                                    ),
                                  ),
                                )
                              : Text(
                                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(color: Colors.white, fontSize: 20),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'User',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    UkTextField(
                      label: 'Display Name',
                      hint: user?.displayName ?? 'Your name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    UkTextField(
                      label: 'Email',
                      hint: user?.email ?? '',
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: UkButton(
                        label: 'Save Changes',
                        variant: UkButtonVariant.primary,
                        size: UkButtonSize.medium,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updates coming soon!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // API Keys Section
              const Text(
                'API Keys',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
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
                    if (_isLoadingKey)
                      const Center(child: UkSpinner())
                    else if (_lastApiKey != null) ...[
                      const Text(
                        'Current Key',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrayBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_lastApiKey!.substring(0, 8)}...',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copy key',
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: _lastApiKey!));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('API key copied!')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.statusFailed),
                              tooltip: 'Clear key',
                              onPressed: () async {
                                await _prefsService.clearLastUsedApiKey();
                                setState(() => _lastApiKey = null);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'No API key configured.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: UkButton(
                        label: _isGeneratingKey ? 'Generating...' : '+ Create New API Key',
                        variant: UkButtonVariant.outline,
                        size: UkButtonSize.medium,
                        icon: _isGeneratingKey ? null : Icons.add,
                        onPressed: _isGeneratingKey ? null : _generateApiKey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Billing Section
              const Text(
                'Billing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
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
                        const Text(
                          'Current Plan',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        UkBadge('Free', variant: UkBadgeVariant.primary),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bandwidth Usage',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    UkProgress(
                      value: 0.12,
                      variant: UkProgressVariant.primary,
                      size: UkProgressSize.medium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1.2 GB / 10 GB',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    UkButton(
                      label: 'Upgrade Plan',
                      variant: UkButtonVariant.primary,
                      size: UkButtonSize.medium,
                      icon: Icons.star_outline,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Plan upgrades coming soon!')),
                        );
                      },
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
