import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isGeneratingKey = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _apiKeyController.dispose();
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

      // Show dialog with the generated API key
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
                  color: Colors.grey[200],
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
              const Text(
                '⚠️ Important: Copy this key now. You won\'t be able to see it again!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
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
                // Auto-fill the text field with the generated key
                setState(() {
                  _apiKeyController.text = apiKey;
                });
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy & Use'),
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
      final uploadStream = storageService.uploadZipFileWithProgress(
        _apiKeyController.text,
        _selectedFile!.bytes!,
        _selectedFile!.name,
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
              if (_apiKeyController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter your API key first')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeploymentsScreen(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'API Key',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isGeneratingKey ? null : _generateApiKey,
                          icon: _isGeneratingKey
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.vpn_key, size: 18),
                          label: Text(
                              _isGeneratingKey ? 'Generating...' : 'Generate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your API key (fk_...)',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                      'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _pickAndUploadFile,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload and Deploy'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
