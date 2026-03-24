import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:netlaunch_api/netlaunch_api.dart';
import 'package:netlaunch_ui/netlaunch_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserPreferencesService? _prefsService;
  final _usageService = UsageService();
  String? _lastApiKey;
  bool _isLoadingKey = true;
  bool _isGeneratingKey = false;
  List<ApiKeyInfo>? _apiKeys;
  bool _isLoadingApiKeys = true;
  int _totalDeployments = 0;
  bool _isLoadingDeployments = true;

  // Firebase config state
  bool _isLoadingConfig = true;
  bool _isSavingConfig = false;
  bool _isDeletingConfig = false;
  bool _hasFirebaseConfig = false;
  String? _configProjectId;
  String? _configClientEmail;
  String? _configSavedAt;

  static const int _freeDeploymentLimit = 50;

  UserPreferencesService _getPrefsService() {
    return _prefsService ??= UserPreferencesService(
      Provider.of<AuthProvider>(context, listen: false),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApiKey();
      _loadApiKeysFromFirestore();
      _loadDeploymentCount();
      _loadFirebaseConfig();
    });
  }

  Future<void> _loadApiKey() async {
    final key = await _getPrefsService().getLastUsedApiKey();
    if (mounted) {
      setState(() {
        _lastApiKey = key;
        _isLoadingKey = false;
      });
    }
  }

  Future<void> _loadApiKeysFromFirestore() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      final keys = await _usageService.getUserApiKeys(user.uid);
      if (mounted) {
        setState(() {
          _apiKeys = keys;
          _isLoadingApiKeys = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingApiKeys = false);
      }
    }
  }

  Future<void> _loadDeploymentCount() async {
    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final deployments = await functionsService.listUserDeployments();
      if (mounted) {
        setState(() {
          _totalDeployments = deployments.length;
          _isLoadingDeployments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDeployments = false);
      }
    }
  }

  Future<void> _generateApiKey() async {
    setState(() => _isGeneratingKey = true);

    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final apiKey = await functionsService.generateApiKey();
      await _getPrefsService().saveLastUsedApiKey(apiKey);
      if (mounted) {
        setState(() => _lastApiKey = apiKey);
        await Clipboard.setData(ClipboardData(text: apiKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New API key generated and copied!'), backgroundColor: Colors.green),
        );
        // Refresh the API keys list
        _loadApiKeysFromFirestore();
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

  Future<void> _loadFirebaseConfig() async {
    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final config = await functionsService.getFirebaseConfig();
      if (mounted) {
        setState(() {
          _hasFirebaseConfig = config['hasConfig'] == true;
          _configProjectId = config['projectId'];
          _configClientEmail = config['clientEmail'];
          _configSavedAt = config['savedAt'];
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _uploadFirebaseConfig() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final jsonString = String.fromCharCodes(result.files.single.bytes!);

    setState(() => _isSavingConfig = true);

    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final response = await functionsService.saveFirebaseConfig(jsonString);
      if (mounted) {
        setState(() {
          _hasFirebaseConfig = true;
          _configProjectId = response['projectId'];
          _configClientEmail = response['clientEmail'];
          _isSavingConfig = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase config saved for project "${response['projectId']}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingConfig = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFirebaseConfig() async {
    setState(() => _isDeletingConfig = true);
    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      await functionsService.deleteFirebaseConfig();
      if (mounted) {
        setState(() {
          _hasFirebaseConfig = false;
          _configProjectId = null;
          _configClientEmail = null;
          _configSavedAt = null;
          _isDeletingConfig = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase config removed. Deploys will use NetLaunch hosting.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingConfig = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatRelativeDate(DateTime? date) {
    if (date == null) return 'Never';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return _formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final deploymentProgress = _totalDeployments / _freeDeploymentLimit;

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
                          backgroundColor: AppColors.teal,
                          child: user?.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.photoUrl!,
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
                    // Show locally cached key for quick copy
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
                                await _getPrefsService().clearLastUsedApiKey();
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

                    // Firestore API keys list
                    if (_isLoadingApiKeys)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: UkSpinner()),
                      )
                    else if (_apiKeys != null && _apiKeys!.isNotEmpty) ...[
                      const UkDivider(),
                      const SizedBox(height: 12),
                      const Text(
                        'All Keys',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...(_apiKeys!.map((key) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightGrayBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.key, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${key.keyHash.length > 12 ? key.keyHash.substring(0, 12) : key.keyHash}...',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Created ${_formatDate(key.createdAt)}  ·  ${key.usageCount} requests  ·  Last used ${_formatRelativeDate(key.lastUsed)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))),
                      const SizedBox(height: 8),
                    ],

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

              // Firebase Configuration Section
              const Text(
                'Firebase Configuration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Deploy to your own Firebase project instead of NetLaunch hosting.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: _isLoadingConfig
                    ? const Center(child: UkSpinner())
                    : _hasFirebaseConfig
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_done, color: AppColors.teal, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Self-Hosted Mode Active',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.teal),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrayBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Project: $_configProjectId',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Account: $_configClientEmail',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'All your deployments will go to this Firebase project.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  UkButton(
                                    label: 'Update Config',
                                    variant: UkButtonVariant.outline,
                                    size: UkButtonSize.small,
                                    icon: Icons.upload_file,
                                    onPressed: _isSavingConfig ? null : _uploadFirebaseConfig,
                                  ),
                                  const SizedBox(width: 12),
                                  UkButton(
                                    label: _isDeletingConfig ? 'Removing...' : 'Remove',
                                    variant: UkButtonVariant.text,
                                    size: UkButtonSize.small,
                                    icon: Icons.delete_outline,
                                    onPressed: _isDeletingConfig ? null : _removeFirebaseConfig,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No Firebase config set. Deploys go to NetLaunch hosting.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              UkAlert(
                                message: 'To self-host: Go to Firebase Console → Project Settings → Service accounts → Generate new private key. Upload the JSON file below.',
                                type: UkAlertType.info,
                                dismissible: false,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: UkButton(
                                  label: _isSavingConfig ? 'Validating...' : 'Upload Service Account JSON',
                                  variant: UkButtonVariant.primary,
                                  size: UkButtonSize.medium,
                                  icon: _isSavingConfig ? null : Icons.upload_file,
                                  onPressed: _isSavingConfig ? null : _uploadFirebaseConfig,
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
                      'Deployments Used',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingDeployments
                        ? UkProgress(
                            value: 0,
                            variant: UkProgressVariant.primary,
                            size: UkProgressSize.medium,
                          )
                        : UkProgress(
                            value: deploymentProgress.clamp(0.0, 1.0),
                            variant: UkProgressVariant.primary,
                            size: UkProgressSize.medium,
                          ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoadingDeployments
                          ? 'Loading...'
                          : '$_totalDeployments / $_freeDeploymentLimit deployments',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
