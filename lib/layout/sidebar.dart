import 'dart:async';

import 'package:crm_interface/core/navigation/app_screen.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:flutter/material.dart';

String accountInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.first.isEmpty) return '?';
  return (words.length > 1
          ? '${words[0].characters.first}${words[1].characters.first}'
          : words.first.characters.take(2).join())
      .toUpperCase();
}

class SideBar extends StatelessWidget {
  const SideBar({
    super.key,
    required this.activeScreen,
    required this.onScreenSelected,
    this.accountProfile,
    this.accountLoading = false,
    this.accountError = false,
    this.loggingOut = false,
    this.onReloadProfile,
    this.onLogout,
  });

  final AppScreen activeScreen;
  final ValueChanged<AppScreen> onScreenSelected;
  final AuthProfile? accountProfile;
  final bool accountLoading;
  final bool accountError;
  final bool loggingOut;
  final VoidCallback? onReloadProfile;
  final VoidCallback? onLogout;

  Widget logo() {
    return Container(
      margin: EdgeInsets.only(top: 15, bottom: 15),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Image.asset("assets/images/logo.jpg", width: 44, height: 44),
    );
  }

  Widget sideBarButton(AppScreen buttonScreen, IconData icon) {
    final bool isActive = activeScreen == buttonScreen;

    return InkWell(
      onTap: () => onScreenSelected(buttonScreen),
      hoverColor: AppColors.hoveredElement,
      borderRadius: BorderRadius.all(Radius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppColors.activeElement : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        width: 44,
        height: 44,
        child: Icon(icon, color: AppColors.sidebarElement),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebarBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          spacing: 10,
          children: [
            logo(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  spacing: 10,
                  children: [
                    sideBarButton(AppScreen.customers, Icons.badge_outlined),
                    sideBarButton(AppScreen.tasks, Icons.task_alt_outlined),
                    sideBarButton(
                      AppScreen.analytics,
                      Icons.analytics_outlined,
                    ),
                    sideBarButton(
                      AppScreen.catalog,
                      Icons.shopping_cart_outlined,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                spacing: 10,
                children: [
                  _AccountMenu(
                    profile: accountProfile,
                    loading: accountLoading,
                    error: accountError,
                    loggingOut: loggingOut,
                    onReloadProfile: onReloadProfile,
                    onLogout: onLogout,
                  ),
                  const Tooltip(
                    message: 'Параметры — пока не реализованы',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        key: Key('sidebar-settings'),
                        onPressed: null,
                        disabledColor: AppColors.sidebarElement,
                        icon: Icon(Icons.settings_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMenu extends StatefulWidget {
  const _AccountMenu({
    required this.profile,
    required this.loading,
    required this.error,
    required this.loggingOut,
    required this.onReloadProfile,
    required this.onLogout,
  });

  final AuthProfile? profile;
  final bool loading;
  final bool error;
  final bool loggingOut;
  final VoidCallback? onReloadProfile;
  final VoidCallback? onLogout;

  @override
  State<_AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<_AccountMenu> {
  final _controller = MenuController();
  final _hoveredRegions = <String>{};
  Timer? _closeTimer;

  void _leaveRegion(String name) {
    _hoveredRegions.remove(name);
    if (!mounted || !_controller.isOpen || _hoveredRegions.isNotEmpty) return;
    _closeTimer?.cancel();
    // A short grace period lets the pointer cross gaps between overlays.
    _closeTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _hoveredRegions.isEmpty) _controller.close();
    });
  }

  Widget _hoverRegion(String name, Widget child) {
    return MouseRegion(
      onEnter: (_) {
        _hoveredRegions.add(name);
        _closeTimer?.cancel();
      },
      onExit: (_) => _leaveRegion(name),
      child: child,
    );
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile?.displayName;
    final tooltip = widget.loading
        ? 'Загрузка профиля…'
        : widget.error
        ? 'Аккаунт — профиль недоступен'
        : name ?? 'Аккаунт';
    final menuStyle = MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(AppColors.background),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(5),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.notActiveBorder),
        ),
      ),
    );
    return MenuAnchor(
      controller: _controller,
      onClose: () {
        _closeTimer?.cancel();
        // Removed overlays do not send MouseRegion.onExit.
        _hoveredRegions.removeAll(['menu', 'profile']);
      },
      style: menuStyle.copyWith(alignment: Alignment.topRight),
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
                SubmenuButton(
                  onClose: () => _leaveRegion('profile'),
                  leadingIcon: const Icon(Icons.info_outline, size: 18),
                  menuStyle: menuStyle,
                  menuChildren: [
                    _hoverRegion(
                      'profile',
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.loading)
                              const MenuItemButton(
                                child: Text('Загрузка профиля…'),
                              )
                            else if (widget.error || widget.profile == null)
                              MenuItemButton(
                                onPressed: widget.onReloadProfile,
                                leadingIcon: const Icon(
                                  Icons.refresh,
                                  size: 18,
                                ),
                                child: const Text('Повторить загрузку профиля'),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 240,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 8,
                                    children: [
                                      SelectableText(name!),
                                      Text('Логин: ${widget.profile!.login}'),
                                      Text('Роль: ${widget.profile!.roleName}'),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  child: const Text('Об аккаунте'),
                ),
                const Tooltip(
                  message: 'Настройки аккаунта пока не реализованы',
                  child: MenuItemButton(
                    leadingIcon: Icon(Icons.manage_accounts_outlined, size: 18),
                    child: Text('Настройки аккаунта'),
                  ),
                ),
                const Divider(height: 9),
                MenuItemButton(
                  onPressed: widget.loggingOut ? null : widget.onLogout,
                  leadingIcon: const Icon(Icons.logout_rounded, size: 18),
                  child: const Text('Выход'),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => _hoverRegion(
        'avatar',
        Tooltip(
          message: widget.loggingOut ? 'Выход…' : tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: TextButton(
              key: const Key('sidebar-account'),
              onPressed: widget.loggingOut
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                foregroundColor: const WidgetStatePropertyAll(
                  Color(0xFF475467),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.hovered)
                      ? AppColors.strongBorder
                      : AppColors.notActiveBorder;
                }),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              child: widget.loading || widget.loggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : name == null
                  ? const Icon(Icons.person_outline, size: 22)
                  : Text(
                      accountInitials(name),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
