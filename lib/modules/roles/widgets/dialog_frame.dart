import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/core/keyboard/dialog_keyboard_scope.dart';

class RoleDialogFrame extends StatelessWidget {
  const RoleDialogFrame({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.actions,
    this.busy = false,
    this.danger = false,
    this.keyboardKey,
    this.hasChanges,
    this.onSubmit,
  });
  final String title;
  final String description;
  final Widget body;
  final List<Widget> actions;
  final bool busy;
  final bool danger;
  final GlobalKey<DialogKeyboardScopeState>? keyboardKey;
  final bool Function()? hasChanges;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => DialogKeyboardScope(
    key: keyboardKey,
    busy: busy,
    hasChanges: hasChanges,
    onSubmit: onSubmit,
    child: Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  spacing: 12,
                  children: [
                    Icon(
                      danger
                          ? Icons.delete_outline
                          : Icons.admin_panel_settings_outlined,
                      color: danger
                          ? const Color(0xFFB42318)
                          : AppColors.activeElement,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: busy
                          ? null
                          : () => keyboardKey == null
                                ? Navigator.of(context).pop()
                                : keyboardKey!.currentState?.requestClose(),
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ],
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutted,
                  ),
                ),
                const SizedBox(height: 24),
                body,
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.notActiveBorder),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 9,
                  runSpacing: 9,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RoleMessage extends StatelessWidget {
  const RoleMessage(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF1F0) : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.notActiveBorder),
    ),
    child: Text(
      message,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: error ? const Color(0xFFB42318) : AppColors.textMutted,
      ),
    ),
  );
}
