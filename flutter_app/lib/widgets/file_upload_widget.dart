import 'package:flutter/material.dart';

class FileUploadWidget extends StatelessWidget {
  final Function(String) onFileSelected;
  final String? selectedFileName;
  final VoidCallback? onPickFile;

  const FileUploadWidget({
    super.key,
    required this.onFileSelected,
    this.selectedFileName,
    this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPickFile,
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                selectedFileName != null
                    ? 'Selected: $selectedFileName'
                    : 'Select a ZIP file to upload',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              if (selectedFileName != null) ...[
                const SizedBox(height: 8),
                Text(
                  selectedFileName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

