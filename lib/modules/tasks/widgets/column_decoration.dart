import 'package:flutter/material.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';

/// Decorations only: AppFlowy retains layout, scrolling and drag targets.
class TaskColumnFrames extends CustomPainter {
  TaskColumnFrames({required this.columns, required this.scrollController})
    : super(repaint: scrollController);

  static const slotWidth = 310.0;
  static const margin = 8.0;
  final int columns;
  final ScrollController scrollController;

  @override
  void paint(Canvas canvas, Size size) {
    // During a board replacement both old and new views may briefly be attached.
    final offset = scrollController.hasClients
        ? scrollController.positions.last.pixels
        : 0.0;
    final fill = Paint()..color = AppColors.taskColumnBackground;
    final stroke = Paint()
      ..color = AppColors.notActiveBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var index = 0; index < columns; index++) {
      // Match AppFlowy's removal of the first left / last right margin.
      final left = index * slotWidth + (index == 0 ? 0 : margin) - offset;
      final right =
          (index + 1) * slotWidth -
          (index == columns - 1 && index != 0 ? 0 : margin) -
          offset;
      if (right < 0 || left > size.width) continue;
      final frame = RRect.fromRectAndRadius(
        Rect.fromLTRB(left + .5, .5, right - .5, size.height - .5),
        const Radius.circular(16),
      );
      canvas.drawRRect(frame, fill);
      canvas.drawRRect(frame, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TaskColumnFrames oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.scrollController != scrollController;
}

class DashedColumnBorder extends CustomPainter {
  const DashedColumnBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(10),
        ),
      );
    final paint = Paint()
      ..color = const Color(0xFFC9CFD9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(metric.extractPath(start, start + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedColumnBorder oldDelegate) => false;
}
