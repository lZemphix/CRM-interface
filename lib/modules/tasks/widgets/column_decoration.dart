import 'package:flutter/material.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';

/// Decorations only: AppFlowy retains layout, scrolling and drag targets.
class TaskColumnFrames extends CustomPainter {
  TaskColumnFrames({
    required this.columns,
    required this.scrollController,
    this.fillColor = AppColors.taskColumnBackground,
    this.borderColor = AppColors.notActiveBorder,
  }) : super(repaint: scrollController);

  static const slotWidth = 250.0;
  static const margin = 8.0;
  final int columns;
  final ScrollController scrollController;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    // During a board replacement both old and new views may briefly be attached.
    final offset = scrollController.hasClients
        ? scrollController.positions.last.pixels
        : 0.0;
    final fill = Paint()..color = fillColor;
    final stroke = Paint()
      ..color = borderColor
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
      oldDelegate.scrollController != scrollController ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}

class DashedColumnBorder extends CustomPainter {
  const DashedColumnBorder({this.color = AppColors.strongBorder});
  final Color color;

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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(metric.extractPath(start, start + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedColumnBorder oldDelegate) =>
      oldDelegate.color != color;
}
