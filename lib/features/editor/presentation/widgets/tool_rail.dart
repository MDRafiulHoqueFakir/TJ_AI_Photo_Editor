import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum EditorTool {
  adjust(Icons.tune, 'Adjust'),
  retouch(Icons.face_retouching_natural, 'Retouch'),
  body(Icons.accessibility_new, 'Body'),
  ai(Icons.auto_awesome, 'AI'),
  filter(Icons.filter_vintage, 'Filter'),
  text(Icons.title, 'Text'),
  sticker(Icons.emoji_emotions, 'Sticker'),
  layers(Icons.layers, 'Layers'),
  crop(Icons.crop, 'Crop');

  const EditorTool(this.icon, this.label);
  final IconData icon;
  final String label;
}

class ToolRail extends StatelessWidget {
  const ToolRail({super.key, required this.active, required this.onSelect});

  final EditorTool active;
  final ValueChanged<EditorTool> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: EditorTool.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tool = EditorTool.values[i];
          final selected = tool == active;
          return GestureDetector(
            onTap: () => onSelect(tool),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tool.icon,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tool.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
