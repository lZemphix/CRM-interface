import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

class EmployeeDialogFrame extends StatelessWidget {
  const EmployeeDialogFrame({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.body,
    required this.actions,
    this.busy = false,
    this.danger = false,
    this.note,
    this.keyboardKey,
    this.hasChanges,
    this.onSubmit,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget body;
  final List<Widget> actions;
  final bool busy;
  final bool danger;
  final String? note;
  final GlobalKey<DialogKeyboardScopeState>? keyboardKey;
  final bool Function()? hasChanges;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.activeElement;
    return DialogKeyboardScope(
      key: keyboardKey,
      busy: busy,
      hasChanges: hasChanges,
      onSubmit: onSubmit,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: context.colors.surface,
            counterStyle: const TextStyle(fontSize: 10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: context.colors.strongBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: context.colors.accent),
            ),
          ),
        ),
        child: Dialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 548),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 21),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.taskCardText,
                                ),
                              ),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: context.colors.textMutted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('employee-dialog-close'),
                          tooltip: 'Закрыть',
                          onPressed: busy
                              ? null
                              : () => keyboardKey == null
                                    ? Navigator.of(context).pop()
                                    : keyboardKey!.currentState?.requestClose(),
                          style: IconButton.styleFrom(
                            minimumSize: Size.zero,
                            fixedSize: const Size(28, 28),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.close,
                            size: 19,
                            color: context.colors.textFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    body,
                    const SizedBox(height: 20),
                    Divider(height: 1, color: context.colors.notActiveBorder),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 9,
                      runSpacing: 9,
                      children: actions,
                    ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          note!,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textFaint,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmployeeInfoBox extends StatelessWidget {
  const EmployeeInfoBox(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: warning ? context.colors.warningSoft : context.colors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 9,
      children: [
        Icon(
          warning ? Icons.info_outline : Icons.lock_outline,
          size: 16,
          color: warning ? context.colors.warning : context.colors.textFaint,
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: warning
                  ? context.colors.warning
                  : context.colors.textMutted,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmployeeFormError extends StatelessWidget {
  const EmployeeFormError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SelectableText(
      message,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
