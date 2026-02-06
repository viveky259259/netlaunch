import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterkit/kit/kit.dart';
import '../services/storage_service.dart';
import '../services/functions_service.dart';
import '../widgets/file_upload_widget.dart';
import 'deployments_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _siteNameController = TextEditingController();
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isGeneratingKey = false;
  double _uploadProgress = 0.0;
  String? _siteNameError;

  void _validateSiteName(String value) {
    setState(() {
      _siteNameError = StorageService.validateSiteName(value.toLowerCase());
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _siteNameController.dispose();
    super.dispose();
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
    setState(() {
      _isGeneratingKey = true;
    });

    try {
      final functionsService =
          Provider.of<FunctionsService>(context, listen: false);
      final apiKey = await functionsService.generateApiKey();

      if (mounted) {
        _showApiKeyDialog(apiKey);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingKey = false;
        });
      }
    }
  }

  void _showApiKeyDialog(String apiKey) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('API Key Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your API key has been generated. Save this key securely - it will not be shown again.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  apiKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              UkAlert(
                message:
                    'Copy this key now. You won\'t be able to see it again!',
                type: UkAlertType.warning,
                dismissible: false,
              ),
            ],
          ),
          actions: [
            UkButton(
              label: 'Cancel',
              variant: UkButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
            UkButton(
              label: 'Copy & Use',
              variant: UkButtonVariant.primary,
              icon: Icons.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: apiKey));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API key copied to clipboard!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                Navigator.of(context).pop();
                setState(() {
                  _apiKeyController.text = apiKey;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadFile() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your API key')),
      );
      return;
    }

    final siteName = _siteNameController.text.toLowerCase().trim();
    final siteNameError = StorageService.validateSiteName(siteName);
    if (siteNameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(siteNameError)),
      );
      return;
    }

    if (_selectedFile == null || _selectedFile!.bytes == null) {
      await _pickFile();
      if (_selectedFile == null || _selectedFile!.bytes == null) {
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storageService =
          Provider.of<StorageService>(context, listen: false);

      final uploadStream = await storageService.uploadZipFileWithProgressAsync(
        _apiKeyController.text,
        _selectedFile!.bytes!,
        _selectedFile!.name,
        siteName,
      );

      uploadStream.listen(
        (snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        },
        onError: (error) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onDone: () {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'File uploaded successfully! Deployment in progress...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Hosting Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please sign in to view deployments')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeploymentsScreen(
                    userId: user.uid,
                    apiKey: _apiKeyController.text,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: UkContainer(
          size: UkContainerSize.medium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // API Key Section
              UkCard(
                header: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key, size: 20),
                        SizedBox(width: 8),
                        Text('API Key'),
                      ],
                    ),
                    UkButton(
                      label:
                          _isGeneratingKey ? 'Generating...' : 'Generate',
                      variant: UkButtonVariant.tonal,
                      size: UkButtonSize.small,
                      icon: _isGeneratingKey ? null : Icons.add,
                      onPressed: _isGeneratingKey ? null : _generateApiKey,
                    ),
                  ],
                ),
                child: UkTextField(
                  controller: _apiKeyController,
                  hint: 'Enter your API key (fk_...)',
                  isPassword: true,
                  prefixIcon: Icons.key,
                ),
              ),
              const SizedBox(height: 16),

              // Site Name Section
              UkCard(
                header: const Row(
                  children: [
                    Icon(Icons.language, size: 20),
                    SizedBox(width: 8),
                    Text('Website Name'),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a unique name for your website URL',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _siteNameController,
                      decoration: InputDecoration(
                        hintText: 'my-awesome-app',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                        suffixText: '.web.app',
                        errorText: _siteNameError,
                      ),
                      onChanged: _validateSiteName,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9-]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.open_in_new,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'https://${_siteNameController.text.toLowerCase().isNotEmpty ? _siteNameController.text.toLowerCase() : "your-site"}.web.app',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // File Upload
              FileUploadWidget(
                onFileSelected: (fileName) {
                  setState(() {
                    _selectedFileName = fileName;
                  });
                },
                selectedFileName: _selectedFileName,
                onPickFile: _pickFile,
              ),
              const SizedBox(height: 24),

              // Upload Button / Progress
              if (_isUploading)
                UkCard(
                  child: Column(
                    children: [
                      UkProgress(
                        value: _uploadProgress,
                        variant: UkProgressVariant.primary,
                        size: UkProgressSize.large,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: UkButton(
                    label: 'Upload and Deploy',
                    variant: UkButtonVariant.primary,
                    size: UkButtonSize.large,
                    icon: Icons.cloud_upload,
                    onPressed: _pickAndUploadFile,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
