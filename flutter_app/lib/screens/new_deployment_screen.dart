import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutterkit/kit/kit.dart';
import 'package:netlaunch_api/netlaunch_api.dart';
import 'package:netlaunch_auth/netlaunch_auth.dart';
import 'package:netlaunch_ui/netlaunch_ui.dart';

class NewDeploymentScreen extends StatefulWidget {
  const NewDeploymentScreen({super.key});

  @override
  State<NewDeploymentScreen> createState() => _NewDeploymentScreenState();
}

class _NewDeploymentScreenState extends State<NewDeploymentScreen> {
  final _siteNameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  UserPreferencesService? _prefsService;
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isGeneratingKey = false;
  double _uploadProgress = 0.0;
  String? _siteNameError;
  String? _uploadError;
  int _selectedMethod = 1; // 0=URL, 1=ZIP, 2=CLI

  UserPreferencesService _getPrefsService() {
    return _prefsService ??= UserPreferencesService(
      Provider.of<AuthProvider>(context, listen: false),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedApiKey());
  }

  Future<void> _loadSavedApiKey() async {
    final savedKey = await _getPrefsService().getLastUsedApiKey();
    if (savedKey != null && mounted) {
      setState(() => _apiKeyController.text = savedKey);
    }
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _validateSiteName(String value) {
    setState(() {
      _siteNameError = StorageService.validateSiteName(value.toLowerCase());
    });
  }

  Future<void> _pickFile() async {
    final storageService = Provider.of<StorageService>(context, listen: false);
    final result = await storageService.pickZipFile();

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFile = result.files.single;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _generateApiKey() async {
    setState(() => _isGeneratingKey = true);

    try {
      final functionsService = Provider.of<FunctionsService>(context, listen: false);
      final apiKey = await functionsService.generateApiKey();
      await _getPrefsService().saveLastUsedApiKey(apiKey);
      if (mounted) {
        setState(() => _apiKeyController.text = apiKey);
        await Clipboard.setData(ClipboardData(text: apiKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key generated and copied!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate API key: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingKey = false);
    }
  }

  Future<void> _deploy() async {
    // Validate
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or generate a deployment key')),
      );
      return;
    }

    final siteName = _siteNameController.text.toLowerCase().trim();
    final siteNameError = StorageService.validateSiteName(siteName);
    if (siteNameError != null) {
      setState(() => _siteNameError = siteNameError);
      return;
    }

    if (_selectedFile == null || _selectedFile!.bytes == null) {
      await _pickFile();
      if (_selectedFile == null || _selectedFile!.bytes == null) return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final uploadStream = await storageService.uploadZipFileWithProgressAsync(
        _apiKeyController.text,
        _selectedFile!.bytes!,
        _selectedFile!.name,
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
              _isUploading = false;
              _uploadProgress = 0.0;
              _uploadError = error.toString();
            });
          }
        },
        onDone: () async {
          await _getPrefsService().saveLastUsedApiKey(_apiKeyController.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Deployed successfully!'),
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
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Deployment',
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
              // Method Selector
              const Text(
                'Deployment Method',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MethodCard(
                    icon: Icons.link,
                    label: 'URL Import',
                    selected: _selectedMethod == 0,
                    enabled: false,
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _MethodCard(
                    icon: Icons.archive_outlined,
                    label: 'ZIP Archive',
                    selected: _selectedMethod == 1,
                    enabled: true,
                    onTap: () => setState(() => _selectedMethod = 1),
                  ),
                  const SizedBox(width: 12),
                  _MethodCard(
                    icon: Icons.terminal,
                    label: 'CLI / Key',
                    selected: _selectedMethod == 2,
                    enabled: true,
                    onTap: () => setState(() => _selectedMethod = 2),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // CLI Method
              if (_selectedMethod == 2) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deploy via CLI',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Generate an API key above or use an existing one.',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '2. Run the deploy command:',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          'npx netlaunch deploy \\\n  --key YOUR_API_KEY \\\n  --site my-app \\\n  --file ./dist.zip',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFF4EC9B0),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Or set the NETLAUNCH_KEY environment variable:',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const SelectableText(
                          'export NETLAUNCH_KEY=fk_your_key_here\nnpx netlaunch deploy -s my-app -f ./dist.zip',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFF4EC9B0),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Deployment Key section for CLI
                      const Text(
                        'Deployment Key',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: UkTextField(
                              controller: _apiKeyController,
                              hint: 'Enter your API key (fk_...)',
                              isPassword: true,
                              prefixIcon: Icons.key,
                            ),
                          ),
                          const SizedBox(width: 12),
                          UkButton(
                            label: _isGeneratingKey ? 'Generating...' : 'Generate',
                            variant: UkButtonVariant.tonal,
                            size: UkButtonSize.medium,
                            icon: _isGeneratingKey ? null : Icons.auto_awesome,
                            onPressed: _isGeneratingKey ? null : _generateApiKey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      UkAlert(
                        message: 'Your site will be live at https://<site-name>.web.app once deployed.',
                        type: UkAlertType.info,
                        dismissible: false,
                      ),
                    ],
                  ),
                ),
              ],

              // ZIP Archive Method
              if (_selectedMethod == 1) ...[
                // Project Name
                const Text(
                  'Project Name',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _siteNameController,
                  decoration: InputDecoration(
                    hintText: 'my-awesome-app',
                    suffixText: '.web.app',
                    errorText: _siteNameError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _validateSiteName,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                    LengthLimitingTextInputFormatter(30),
                  ],
                ),
                if (_siteNameController.text.isNotEmpty && _siteNameError == null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.open_in_new, size: 13, color: AppColors.teal),
                      const SizedBox(width: 4),
                      Text(
                        'https://${_siteNameController.text.toLowerCase()}.web.app',
                        style: const TextStyle(fontSize: 13, color: AppColors.teal),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // Deployment Key
                const Text(
                  'Deployment Key',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: UkTextField(
                        controller: _apiKeyController,
                        hint: 'Enter your API key (fk_...)',
                        isPassword: true,
                        prefixIcon: Icons.key,
                      ),
                    ),
                    const SizedBox(width: 12),
                    UkButton(
                      label: _isGeneratingKey ? 'Generating...' : 'Generate',
                      variant: UkButtonVariant.tonal,
                      size: UkButtonSize.medium,
                      icon: _isGeneratingKey ? null : Icons.auto_awesome,
                      onPressed: _isGeneratingKey ? null : _generateApiKey,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // File Picker
                const Text(
                  'Upload File',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isUploading ? null : _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFileName != null ? AppColors.teal : AppColors.cardBorder,
                        width: _selectedFileName != null ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFileName != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                          size: 48,
                          color: _selectedFileName != null ? AppColors.teal : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFileName != null ? 'File selected' : 'Click to select a ZIP file',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _selectedFileName != null ? AppColors.teal : AppColors.textSecondary,
                          ),
                        ),
                        if (_selectedFileName != null) ...[
                          const SizedBox(height: 8),
                          UkBadge(_selectedFileName!, variant: UkBadgeVariant.primary),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Build Settings
                UkAccordion(
                  items: [
                    UkAccordionItem(
                      title: 'Build Settings',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UkTextField(
                            label: 'Build Command',
                            hint: 'npm run build',
                            prefixIcon: Icons.build_outlined,
                          ),
                          const SizedBox(height: 12),
                          UkTextField(
                            label: 'Output Directory',
                            hint: 'dist',
                            prefixIcon: Icons.folder_outlined,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'These settings are optional for ZIP deployments.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Upload Progress (inline)
                if (_isUploading) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const UkSpinner(),
                        const SizedBox(height: 16),
                        UkProgress(
                          value: _uploadProgress,
                          variant: UkProgressVariant.primary,
                          size: UkProgressSize.large,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Error
                if (_uploadError != null) ...[
                  UkAlert(
                    message: _uploadError!,
                    type: UkAlertType.danger,
                    dismissible: true,
                    onDismissed: () => setState(() => _uploadError = null),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                if (!_isUploading)
                  Row(
                    children: [
                      Expanded(
                        child: UkButton(
                          label: 'Save Draft',
                          variant: UkButtonVariant.outline,
                          size: UkButtonSize.large,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Draft saving coming soon!')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: UkButton(
                          label: 'Deploy Now',
                          variant: UkButtonVariant.primary,
                          size: UkButtonSize.large,
                          icon: Icons.rocket_launch,
                          onPressed: _deploy,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Info box
                UkAlert(
                  message: 'Tip: For best performance, compress your build output into a ZIP file. Make sure index.html is at the root level.',
                  type: UkAlertType.info,
                  dismissible: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.cardBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 24, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!enabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Soon',
                    style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
