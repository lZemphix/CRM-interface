import 'dart:async';

import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

Widget moduleActionButton(
  BuildContext context,
  ModuleDefinition module,
  ModuleAction action,
  VoidCallback close,
) => MenuItemButton(
  key: ValueKey('module-action-${module.id}-${action.id}'),
  leadingIcon: Icon(action.icon, size: 19),
  style: action.destructive
      ? ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(context.colors.danger),
        )
      : null,
  onPressed: () {
    close();
    // Use the stable sidebar context, not the overlay that close() removes.
    unawaited(action.onSelected(context));
  },
  child: Text(action.title),
);

/// A pinned action-only module opens a menu without replacing the active screen.
class ModuleActionsMenu extends StatefulWidget {
  const ModuleActionsMenu({super.key, required this.module});

  final ModuleDefinition module;

  @override
  State<ModuleActionsMenu> createState() => _ModuleActionsMenuState();
}

class _ModuleActionsMenuState extends State<ModuleActionsMenu> {
  final _controller = MenuController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _controller,
    childFocusNode: _focus,
    useRootOverlay: true,
    alignmentOffset: const Offset(10, 0),
    style: MenuStyle(
      alignment: Alignment.topRight,
      backgroundColor: WidgetStatePropertyAll(context.colors.background),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    menuChildren: [
      for (final action in widget.module.actions)
        moduleActionButton(context, widget.module, action, _controller.close),
    ],
    builder: (context, controller, child) => InkWell(
      key: ValueKey('sidebar-module-${widget.module.id}'),
      focusNode: _focus,
      hoverColor: context.colors.hoveredElement,
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
      child: Icon(widget.module.icon, color: context.colors.sidebarElement),
    ),
  );
}
