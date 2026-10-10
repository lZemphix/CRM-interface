import 'package:flutter/material.dart';

import '../../../../core/theme/light/colorscheme.dart';

class CustomerTimelineEntry extends StatelessWidget {
  const CustomerTimelineEntry({
    super.key,
    required this.title,
    required this.metadata,
    this.content,
    this.trailing,
    this.isLast = true,
  });

  final Widget title;
  final Widget? content;
  final String metadata;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!isLast)
        const Positioned(
          left: 7,
          top: 10,
          bottom: 0,
          child: SizedBox(
            width: 1,
            child: ColoredBox(color: AppColors.notActiveBorder),
          ),
        ),
      Padding(
        padding: EdgeInsets.only(left: 30, bottom: isLast ? 0 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF172033),
                    ),
                    child: title,
                  ),
                ),
                ?trailing,
              ],
            ),
            if (content != null) ...[
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMutted,
                  height: 1.5,
                ),
                child: content!,
              ),
            ],
            const SizedBox(height: 5),
            Text(
              metadata,
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
      Positioned(
        left: 0,
        top: 4,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppColors.activeElement, width: 4),
          ),
        ),
      ),
    ],
  );
}
