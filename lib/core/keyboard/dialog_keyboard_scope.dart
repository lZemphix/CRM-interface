import 'package:flutter/material.dart';

import 'command_scope.dart';
import 'keybindings.dart';

class DialogKeyboardScope extends StatefulWidget {
  const DialogKeyboardScope({
    super.key,
    required this.child,
    this.busy = false,
    this.hasChanges,
    this.onSubmit,
    this.onClose,
  });
  final Widget child;
  final bool busy;
  final bool Function()? hasChanges;
  final VoidCallback? onSubmit;
  final VoidCallback? onClose;

  @override
  State<DialogKeyboardScope> createState() => DialogKeyboardScopeState();
}

class DialogKeyboardScopeState extends State<DialogKeyboardScope> {
  bool _confirming = false;

  Future<void> requestClose() async {
    if (widget.busy ||
        _confirming ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    if (widget.onClose == null && !Navigator.of(context).canPop()) return;
    if (widget.hasChanges?.call() ?? false) {
      _confirming = true;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DialogKeyboardScope(
          onClose: () => Navigator.of(context).pop(false),
          child: AlertDialog(
            title: const Text('Отменить изменения?'),
            content: const Text('Введённые данные не будут сохранены.'),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Продолжить редактирование'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Не сохранять'),
              ),
            ],
          ),
        ),
      );
      _confirming = false;
      if (!mounted || confirmed != true || widget.busy) return;
    }
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) requestClose();
    },
    child: CommandScope(
      blockNativeDismiss: true,
      autofocus: true,
      commands: {
        AppCommand.closeDialog: requestClose,
        if (widget.onSubmit != null)
          AppCommand.submitForm: () {
            if (!widget.busy && !_confirming) widget.onSubmit!();
          },
      },
      child: widget.child,
    ),
  );
}
