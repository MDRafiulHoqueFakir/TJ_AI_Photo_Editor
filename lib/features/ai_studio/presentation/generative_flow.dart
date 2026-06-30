import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../application/generative_service.dart';

/// Replicate models used by the generative features.
abstract class GenModels {
  /// Pure background cutout (image in -> transparent cutout out). No prompt.
  static const bgRemove = 'cjwbw/rembg';

  /// Instruction-based photo editing: edits the photo per a text prompt.
  /// Powers hair restyle, generative fill, background change, object removal.
  static const edit = 'black-forest-labs/flux-kontext-pro';
}

/// One reusable cloud-AI flow: pick a photo, (optionally) describe the edit,
/// run the model via the local proxy, then preview + download the result.
/// Honest when the token isn't configured — never fakes a result.
abstract class GenerativeFlow {
  static Future<void> run(
    BuildContext context, {
    required String model,
    String imageKey = 'image',
    String title = 'AI',
    String? promptLabel, // non-null => ask for a prompt
    String defaultPrompt = '',
  }) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;

    String? prompt;
    if (promptLabel != null) {
      prompt = await _askPrompt(context, title, promptLabel, defaultPrompt);
      if (prompt == null || prompt.trim().isEmpty || !context.mounted) return;
    }

    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    _showLoading(context, title);

    final res = await GenerativeService.run(
      model,
      {if (prompt != null) 'prompt': prompt},
      imageBytes: bytes,
      imageKey: imageKey,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // loading
    if (!context.mounted) return;

    if (res.error == 'no-token') {
      showComingSoon(
        context,
        title: 'Connect your AI key',
        reason:
            'This uses a cloud AI model. Launch with run_web.bat and paste your '
            'Replicate token when asked (it is saved for next time). See '
            'docs/GENERATIVE_AI.md. On-device tools work without it.',
      );
      return;
    }
    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Generation failed.')),
      );
      return;
    }
    await _showResult(context, title, res.image!);
  }

  static Future<String?> _askPrompt(
    BuildContext context,
    String title,
    String label,
    String initial,
  ) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  static void _showLoading(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('$title… this can take up to a minute.'),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showResult(
    BuildContext context,
    String title,
    Uint8List image,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(image, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () async {
                      await FileSaver.instance.saveFile(
                        name: 'tj_ai_${DateTime.now().millisecondsSinceEpoch}',
                        bytes: image,
                        fileExtension: 'png',
                        mimeType: MimeType.png,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to downloads.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
