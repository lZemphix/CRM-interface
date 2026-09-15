import 'package:crm_interface/core/navigation/app_screen.dart';
import 'package:crm_interface/modules/customers/screens/customers.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/layout/sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppScreen activeScreen = AppScreen.customers;

  void selectScreen(AppScreen screen) {
    setState(() {
      activeScreen = screen;
    });
  }

  Widget currentScreen() {
    return switch (activeScreen) {
      AppScreen.customers => const CustomersScreen(),
      AppScreen.tasks => const Center(child: Text("tasks")),
      AppScreen.branches => const Center(child: Text("branches")),
      AppScreen.employees => const Center(child: Text("employees")),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideBar(activeScreen: activeScreen, onScreenSelected: selectScreen),
          Expanded(child: currentScreen()),
        ],
      ),
    );
  }
}
