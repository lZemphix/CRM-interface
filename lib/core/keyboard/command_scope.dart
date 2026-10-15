import 'dart:async';

import 'package:flutter/material.dart';

import 'keybindings.dart';

class KeybindingsScope extends InheritedNotifier<KeybindingsController> {
  const KeybindingsScope({
    super.key,
    required KeybindingsController controller,
    required super.child,
  }) : super(notifier: controller);
  static KeybindingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KeybindingsScope>()?.notifier;
}

class KeybindingsHost extends StatefulWidget {
  const KeybindingsHost({super.key, required this.child});
  final Widget child;
  @override
  State<KeybindingsHost> createState() => _KeybindingsHostState();
}

class _KeybindingsHostState extends State<KeybindingsHost> {
  final _controller = KeybindingsController();
  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeybindingsScope(controller: _controller, child: widget.child);
}

sealed class AppCommandIntent extends Intent {
  const AppCommandIntent();
  static AppCommandIntent forCommand(AppCommand command) => switch (command) {
    AppCommand.closeDialog => const CloseDialogIntent(),
    AppCommand.submitForm => const SubmitFormIntent(),
    AppCommand.submitAuth => const SubmitAuthIntent(),
    AppCommand.focusSearch => const FocusSearchIntent(),
  };
}

class CloseDialogIntent extends AppCommandIntent {
  const CloseDialogIntent();
}

class SubmitFormIntent extends AppCommandIntent {
  const SubmitFormIntent();
}

class SubmitAuthIntent extends AppCommandIntent {
  const SubmitAuthIntent();
}

class FocusSearchIntent extends AppCommandIntent {
  const FocusSearchIntent();
}

/// Bindings rebuild in place; focused fields and their drafts are not recreated.
class CommandScope extends StatelessWidget {
  const CommandScope({
    super.key,
    required this.commands,
    required this.child,
    this.blockNativeDismiss = false,
    this.autofocus = false,
  });
  final Map<AppCommand, VoidCallback> commands;
  final Widget child;
  final bool blockNativeDismiss;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final settings = KeybindingsScope.maybeOf(context);
    final mac = Theme.of(context).platform == TargetPlatform.macOS;
    return Shortcuts(
      shortcuts: {
        for (final command in commands.keys)
          for (final activator
              in (settings?.binding(command) ??
                      Keybinding.standard(command, mac: mac))
                  .activators)
            activator: AppCommandIntent.forCommand(command),
      },
      child: Actions(
        actions: {
          for (final entry in commands.entries)
            AppCommandIntent.forCommand(entry.key)
                .runtimeType: CallbackAction<AppCommandIntent>(
              onInvoke: (intent) {
                if (ModalRoute.of(context)?.isCurrent != false) {
                  entry.value();
                }
                return null;
              },
            ),
          // Otherwise WidgetsApp's default Escape still closes a rebound dialog.
          if (blockNativeDismiss)
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => null),
        },
        // A focused scope lets descendant fields autofocus when async forms
        // finish loading, unlike a focused leaf node around the whole dialog.
        child: autofocus
            ? FocusScope(autofocus: true, skipTraversal: true, child: child)
            : Focus(skipTraversal: true, child: child),
      ),
    );
  }
}
