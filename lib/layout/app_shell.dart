import 'package:crm_interface/core/navigation/app_screen.dart';
import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/modules/customers/screens/customers.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:flutter/material.dart';
import 'package:crm_interface/layout/sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.apiClient, required this.tasksRepository});

  final ApiClient apiClient;
  final TasksRepository tasksRepository;

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
      AppScreen.customers => CustomersScreen(apiClient: widget.apiClient),
      AppScreen.tasks => TasksScreen(tasksRepository: widget.tasksRepository,),
      AppScreen.analytics => const Center(child: Text("analytics")),
      AppScreen.catalog => const Center(child: Text("catalog")),
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
