import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

import 'column_decoration.dart';

class TaskColumnFooter extends StatelessWidget {
  const TaskColumnFooter({super.key, required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: onCreate == null
              ? 'Создание в этой колонке недоступно'
              : 'Создать задачу в этой колонке',
          child: CustomPaint(
            foregroundPainter: const DashedColumnBorder(),
            child: OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Новая задача'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AppColors.activeElement,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                overlayColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
