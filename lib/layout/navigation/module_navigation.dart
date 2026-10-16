import 'dart:async';

import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'module_actions_menu.dart';

/// Placement is owned by AppShell; menus never change module availability.
class ModuleNavigation extends StatelessWidget {
  const ModuleNavigation({
    super.key,
    required this.modules,
    required this.activeModuleId,
    required this.pinnedModuleIds,
    required this.onModuleSelected,
    required this.onModulePinChanged,
  });

  final List<ModuleDefinition> modules;
  final String? activeModuleId;
  final Set<String> pinnedModuleIds;
  final ValueChanged<String> onModuleSelected;
  final void Function(String id, bool pinned) onModulePinChanged;

  Future<void> _showPlacementMenu(
    BuildContext context,
    ModuleDefinition module,
    Offset position,
  ) async {
    final pinned = pinnedModuleIds.contains(module.id);
    final overlay =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay!.context.findRenderObject()!
            as RenderBox;
    final localPosition = overlay.globalToLocal(position);
    final result = await showMenu<bool>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromRect(
        localPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: context.colors.background,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.colors.notActiveBorder),
      ),
      items: [
        PopupMenuItem(
          key: ValueKey('module-placement-${module.id}'),
          value: !pinned,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin, size: 18),
              Flexible(
                child: Text(
                  pinned ? 'Убрать из панели' : 'Закрепить в панели',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (result != null && context.mounted) {
      onModulePinChanged(module.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overflow = [
      for (final module in modules)
        if (!pinnedModuleIds.contains(module.id)) module,
    ];
    return SingleChildScrollView(
      child: Column(
        spacing: 10,
        children: [
          for (final module in modules)
            if (pinnedModuleIds.contains(module.id))
              _ContextTarget(
                key: ValueKey('module-target-${module.id}'),
                onRequested: (position) =>
                    unawaited(_showPlacementMenu(context, module, position)),
                child: Tooltip(
                  message: module.title,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Material(
                      color: activeModuleId == module.id
                          ? context.colors.activeElement
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: module.actions.isNotEmpty
                          ? ModuleActionsMenu(module: module)
                          : InkWell(
                              key: ValueKey('sidebar-module-${module.id}'),
                              onTap: () => onModuleSelected(module.id),
                              hoverColor: context.colors.hoveredElement,
                              child: Icon(
                                module.icon,
                                color: context.colors.sidebarElement,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          _OverflowMenu(
            modules: overflow,
            activeModuleId: activeModuleId,
            onSelected: onModuleSelected,
            onContextMenu: (module, position) =>
                unawaited(_showPlacementMenu(context, module, position)),
          ),
        ],
      ),
    );
  }
}

// Both right-click and Shift+F10 use the same placement action.
class _ContextTarget extends StatelessWidget {
  const _ContextTarget({
    super.key,
    required this.onRequested,
    required this.child,
  });

  final ValueChanged<Offset> onRequested;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void openFromKeyboard() {
      final box = context.findRenderObject()! as RenderBox;
      onRequested(box.localToGlobal(box.size.bottomRight(Offset.zero)));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f10, shift: true):
            openFromKeyboard,
        const SingleActivator(LogicalKeyboardKey.contextMenu): openFromKeyboard,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => onRequested(details.globalPosition),
        child: child,
      ),
    );
  }
}

class _OverflowMenu extends StatefulWidget {
  const _OverflowMenu({
    required this.modules,
    required this.activeModuleId,
    required this.onSelected,
    required this.onContextMenu,
  });

  final List<ModuleDefinition> modules;
  final String? activeModuleId;
  final ValueChanged<String> onSelected;
  final void Function(ModuleDefinition module, Offset position) onContextMenu;

  @override
  State<_OverflowMenu> createState() => _OverflowMenuState();
}

class _OverflowMenuState extends State<_OverflowMenu> {
  final _controller = MenuController();
  final _hoveredRegions = <String>{};
  final _buttonFocus = FocusNode();
  Timer? _closeTimer;
  bool _pointerNavigation = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        (_controller.isOpen || _buttonFocus.hasFocus)) {
      _pointerNavigation = false;
    }
    return false;
  }

  Widget _hoverRegion(String name, Widget child) => MouseRegion(
    onEnter: (_) {
      _pointerNavigation = true;
      _hoveredRegions.add(name);
      _closeTimer?.cancel();
    },
    onExit: (_) {
      _hoveredRegions.remove(name);
      if (!_controller.isOpen || _hoveredRegions.isNotEmpty) return;
      _closeTimer?.cancel();
      _closeTimer = Timer(const Duration(milliseconds: 250), () {
        // Keyboard navigation must not lose its menu when the mouse leaves.
        if (mounted && _hoveredRegions.isEmpty && _pointerNavigation) {
          _controller.close();
        }
      });
    },
    child: child,
  );

  @override
  void dispose() {
    _closeTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.modules.any(
      (module) => module.id == widget.activeModuleId,
    );
    return MenuAnchor(
      controller: _controller,
      childFocusNode: _buttonFocus,
      useRootOverlay: true,
      onClose: () {
        _closeTimer?.cancel();
        _hoveredRegions.removeWhere((name) => name != 'button');
      },
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.background),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(5),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        alignment: Alignment.topRight,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.colors.notActiveBorder),
          ),
        ),
      ),
      alignmentOffset: const Offset(10, 0),
      menuChildren: [
        _hoverRegion(
          'menu',
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.modules.isEmpty)
                  const MenuItemButton(child: Text('Все разделы в панели')),
                for (final module in widget.modules)
                  _ContextTarget(
                    key: ValueKey('overflow-target-${module.id}'),
                    onRequested: (position) {
                      _controller.close();
                      widget.onContextMenu(module, position);
                    },
                    child: module.actions.isNotEmpty
                        ? SubmenuButton(
                            key: ValueKey('overflow-module-${module.id}'),
                            leadingIcon: Icon(module.icon, size: 20),
                            menuStyle: MenuStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                context.colors.background,
                              ),
                              surfaceTintColor: WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                            onClose: () =>
                                _hoveredRegions.remove('actions-${module.id}'),
                            menuChildren: [
                              for (final action in module.actions)
                                _hoverRegion(
                                  'actions-${module.id}',
                                  moduleActionButton(
                                    context,
                                    module,
                                    action,
                                    _controller.close,
                                  ),
                                ),
                            ],
                            child: Text(module.title),
                          )
                        : MenuItemButton(
                            key: ValueKey('overflow-module-${module.id}'),
                            autofocus: module == widget.modules.first,
                            onPressed: () {
                              _controller.close();
                              widget.onSelected(module.id);
                            },
                            leadingIcon: Icon(module.icon, size: 20),
                            trailingIcon: module.id == widget.activeModuleId
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: context.colors.accent,
                                  )
                                : null,
                            child: Text(module.title),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => _hoverRegion(
        'button',
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            key: const Key('sidebar-more-modules'),
            focusNode: _buttonFocus,
            tooltip: 'Другие разделы',
            style: IconButton.styleFrom(
              foregroundColor: context.colors.sidebarElement,
              backgroundColor: active
                  ? context.colors.activeElement
                  : Colors.transparent,
              hoverColor: context.colors.hoveredElement,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.more_horiz),
          ),
        ),
      ),
    );
  }
}
