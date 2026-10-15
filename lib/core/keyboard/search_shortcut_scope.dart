import 'package:flutter/material.dart';

import 'command_scope.dart';
import 'keybindings.dart';

/// Allows the current section's search to be focused from the sidebar too.
class SearchShortcutScope extends StatefulWidget {
  const SearchShortcutScope({super.key, required this.child});
  final Widget child;
  @override
  State<SearchShortcutScope> createState() => _SearchShortcutScopeState();
}

class _SearchShortcutScopeState extends State<SearchShortcutScope> {
  FocusNode? target;
  @override
  Widget build(BuildContext context) => _SearchOwner(
    owner: this,
    child: CommandScope(
      autofocus: true,
      commands: {
        AppCommand.focusSearch: () {
          final node = target;
          if (node?.context != null && node!.canRequestFocus) {
            node.requestFocus();
          }
        },
      },
      child: widget.child,
    ),
  );
}

class _SearchOwner extends InheritedWidget {
  const _SearchOwner({required this.owner, required super.child});
  final _SearchShortcutScopeState owner;
  @override
  bool updateShouldNotify(_SearchOwner oldWidget) => oldWidget.owner != owner;
}

class RegisterSearchFocus extends StatefulWidget {
  const RegisterSearchFocus({
    super.key,
    required this.node,
    required this.child,
  });
  final FocusNode node;
  final Widget child;
  @override
  State<RegisterSearchFocus> createState() => _RegisterSearchFocusState();
}

class _RegisterSearchFocusState extends State<RegisterSearchFocus> {
  _SearchShortcutScopeState? _owner;

  void _clear(FocusNode node) {
    if (identical(_owner?.target, node)) _owner?.target = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clear(widget.node);
    _owner = context.dependOnInheritedWidgetOfExactType<_SearchOwner>()?.owner;
    _owner?.target = widget.node;
  }

  @override
  void didUpdateWidget(covariant RegisterSearchFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clear(oldWidget.node);
    _owner?.target = widget.node;
  }

  @override
  void dispose() {
    _clear(widget.node);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
