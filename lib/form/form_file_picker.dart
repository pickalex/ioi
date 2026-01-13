import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' hide FormFieldState;
import 'package:flutter/material.dart' hide FormFieldState;
import 'package:image_picker/image_picker.dart';
import 'form_fields.dart';
import 'form_state.dart';

/// 文件/图片上传表单字段
/// 支持从相册、相机添加图片，以及选择 PDF 文件
/// 网格显示缩略图或文件图标，支持预览
class FormFilePickerField extends StatelessWidget {
  final String label;
  final List<String> files; // File paths
  final ValueChanged<List<String>> onFilesChange;
  final int maxFiles;
  final int columnsPerRow;
  final bool isRequired;
  final FormFieldBorderType borderType;
  final bool allowPdf;

  /// 错误信息，支持 String 或 String? Function(BuildContext)
  final dynamic errorMessage;
  final Widget Function(BuildContext context)? helpBuilder;
  final FormFieldState<List<String>>? fieldState;

  FormFilePickerField({
    Key? key,
    required this.label,
    required this.files,
    required this.onFilesChange,
    this.maxFiles = 9,
    this.columnsPerRow = 3,
    this.isRequired = false,
    this.borderType = FormFieldBorderType.full,
    this.allowPdf = false,
    this.errorMessage,
    this.helpBuilder,
    this.fieldState,
  }) : super(key: key ?? fieldState?.key);

  /// 状态绑定构造函数
  FormFilePickerField.state({
    Key? key,
    required FormFieldState<List<String>> state,
    required this.label,
    this.maxFiles = 9,
    this.columnsPerRow = 3,
    this.isRequired = false,
    this.borderType = FormFieldBorderType.full,
    this.allowPdf = false,
    this.helpBuilder,
  })  : files = state.value,
        onFilesChange = state.didChange,
        fieldState = state,
        errorMessage = null,
        super(key: key ?? state.key);

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          _addFiles(pickedFiles.map((e) => e.path).toList());
        }
      } else {
        final XFile? pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          _addFiles([pickedFile.path]);
        }
      }
    } catch (e) {
      debugPrint("Pick image failed: $e");
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .map((e) => e.path)
            .where((path) => path != null)
            .cast<String>()
            .toList();
        _addFiles(paths);
      }
    } catch (e) {
      debugPrint("Pick file failed: $e");
    }
  }

  void _addFiles(List<String> newPaths) {
    // 过滤掉重复的 (可选)
    // final uniqueNewPaths = newPaths.where((p) => !files.contains(p)).toList();
    final result = [...files, ...newPaths];
    if (result.length > maxFiles) {
      onFilesChange(result.sublist(0, maxFiles));
    } else {
      onFilesChange(result);
    }
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text("从相册选择图片"),
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(context, ImageSource.gallery);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("拍照"),
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(context, ImageSource.camera);
            },
          ),
          if (allowPdf)
            CupertinoActionSheetAction(
              child: const Text("选择 PDF 文件"),
              onPressed: () {
                Navigator.pop(ctx);
                _pickFile(context);
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: const Text("取消"),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _previewFile(BuildContext context, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FilePreviewPage(filePath: path),
        fullscreenDialog: true,
      ),
    );
  }

  bool _isPdf(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    final config = FormFieldConfig.maybeOf(context);
    final effectiveRowHeight =
        config?.rowHeight ?? FormFieldDefaults.minRowHeight;
    final effectiveHPadding =
        config?.horizontalPadding ?? FormFieldDefaults.horizontalPadding;
    final effectiveVPadding =
        config?.verticalPadding ?? FormFieldDefaults.verticalPadding;
    final effectiveSpacing = config?.spacing ?? FormFieldDefaults.spacing;

    // Calculate grid layout
    // We assume the grid takes full width minus padding
    // If inside a FormField structure, it might differ.
    // Standard margin for form fields content area.
    final totalHorizontalPadding = effectiveHPadding * 2;
    final crossAxisCount = columnsPerRow;
    final double spacing = effectiveSpacing;
    // itemSize = (totalWidth - PADDING - (count-1)*spacing) / count
    final double itemSize =
        (width - totalHorizontalPadding - (spacing * (crossAxisCount - 1))) /
            crossAxisCount;

    // 错误信息逻辑
    String? resolvedErrorMessage;
    if (errorMessage is String) {
      resolvedErrorMessage = errorMessage;
    } else if (errorMessage is String? Function(BuildContext)) {
      resolvedErrorMessage =
          (errorMessage as String? Function(BuildContext))(context);
    } else if (errorMessage is String? Function()) {
      resolvedErrorMessage = (errorMessage as String? Function())();
    }

    final effectiveErrorMessage = resolvedErrorMessage ??
        (fieldState?.hasInteracted == true ? fieldState?.errorMessage : null);
    final hasError =
        effectiveErrorMessage != null && effectiveErrorMessage.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: effectiveHPadding,
                vertical: effectiveVPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label Row
                  Row(
                    children: [
                      Expanded(
                        child: FormFieldLabelSection(
                          label: label,
                          isRequired: isRequired,
                          helperBuilder: helpBuilder,
                        ),
                      ),
                      Text(
                        "${files.length}/$maxFiles",
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      )
                    ],
                  ),
                  SizedBox(
                      height:
                          effectiveSpacing), // Spacing between label and grid

                  // Grid
                  if (files.isEmpty &&
                      maxFiles > 0) // No files, show Add Button only
                    _buildAddButton(context, itemSize)
                  else
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        ...files.asMap().entries.map((entry) {
                          final index = entry.key;
                          final path = entry.value;
                          return _buildFileItem(context, path, itemSize, () {
                            // Remove
                            final newFiles = List<String>.from(files);
                            newFiles.removeAt(index);
                            onFilesChange(newFiles);
                          });
                        }),
                        if (files.length < maxFiles)
                          _buildAddButton(context, itemSize),
                      ],
                    ),
                ],
              ),
            ),
            FormDivider(
              type: borderType,
              color: hasError ? theme.colorScheme.error.withOpacity(0.5) : null,
            ),
          ],
        ),
        if (hasError)
          Positioned(
            bottom: 2,
            right: effectiveHPadding,
            child: Text(
              effectiveErrorMessage,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(
      BuildContext context, String path, double size, VoidCallback onDelete) {
    return GestureDetector(
      onTap: () => _previewFile(context, path),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildThumbnail(path),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String path) {
    if (_isPdf(path)) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                path.split('/').last,
                style: const TextStyle(fontSize: 8, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (path.startsWith("http")) {
      return Image.network(path, fit: BoxFit.cover);
    } else {
      return Image.file(File(path), fit: BoxFit.cover);
    }
  }

  Widget _buildAddButton(BuildContext context, double size) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showActionSheet(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.colorScheme.primary.withOpacity(0.8)),
            const SizedBox(height: 4),
            Text(
              "添加",
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilePreviewPage extends StatelessWidget {
  final String filePath;
  const _FilePreviewPage({required this.filePath});

  bool get isPdf => filePath.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for media preview
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isPdf ? "PDF 预览" : "图片预览",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: isPdf ? _buildPdfPreview() : _buildImagePreview(),
      ),
    );
  }

  Widget _buildImagePreview() {
    return InteractiveViewer(
      child: filePath.startsWith("http")
          ? Image.network(filePath)
          : Image.file(File(filePath)),
    );
  }

  Widget _buildPdfPreview() {
    // 简单的 PDF 预览占位符，支持用第三方库打开（如果有）
    // 这里暂时只显示图标和文件名
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            filePath.split('/').last,
            style: const TextStyle(fontSize: 16, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            "预览 PDF 需要集成 PDF 阅读器组件",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
