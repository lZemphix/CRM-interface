import 'package:crm_interface/core/navigation/app_screen.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:flutter/material.dart';

class SideBar extends StatelessWidget {
  const SideBar({
    super.key,
    required this.activeScreen,
    required this.onScreenSelected,
  });

  final AppScreen activeScreen;
  final ValueChanged<AppScreen> onScreenSelected;

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
            sideBarButton(AppScreen.customers, Icons.people_alt_outlined),
            sideBarButton(AppScreen.tasks, Icons.task_alt_outlined),
            sideBarButton(AppScreen.branches, Icons.home_mini_outlined),
            sideBarButton(AppScreen.employees, Icons.people_outline),
          ],
        ),
      ),
    );
  }
}
