import 'package:flutter/material.dart';
import 'package:flutterkit/kit/kit.dart';

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
    final cs = Theme.of(context).colorScheme;
    final hasFile = selectedFileName != null;

    return UkCard(
      child: InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasFile ? cs.primary : cs.outlineVariant,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                hasFile ? Icons.check_circle : Icons.cloud_upload_outlined,
                size: 56,
                color: hasFile ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasFile
                    ? 'File selected'
                    : 'Click to select a ZIP file',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: hasFile ? cs.primary : cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              if (hasFile) ...[
                const SizedBox(height: 8),
                UkBadge(
                  selectedFileName!,
                  variant: UkBadgeVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
