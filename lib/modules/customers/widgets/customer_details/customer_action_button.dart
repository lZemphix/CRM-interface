import 'package:flutter/material.dart';

import '../../../../core/theme/light/colorscheme.dart';

/// Client header actions follow btn-primary / btn-ghost in crm_template.html.
class CustomerActionButton extends StatelessWidget {
  const CustomerActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(100, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.textMutted
            : primary
            ? Colors.white
            : const Color(0xFF172033),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.notActiveBorder;
        }
        final highlighted = states.any(
          {
            WidgetState.hovered,
            WidgetState.pressed,
            WidgetState.focused,
          }.contains,
        );
        if (primary) {
          return highlighted
              ? AppColors.activeElementHover
              : AppColors.activeElement;
        }
        return states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)
            ? AppColors.background
            : Colors.white;
      }),
      side: WidgetStateProperty.resolveWith(
        (states) => primary
            ? BorderSide.none
            : BorderSide(
                color:
                    states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? AppColors.textFaint
                    : AppColors.strongBorder,
              ),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: const Duration(milliseconds: 160),
    ),
    child: Text(label),
  );
}
