import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:flutter/material.dart';

Widget sectionRefreshButton(SectionRefreshController controller) =>
    AnimatedBuilder(
      animation: controller,
      builder: (_, _) => IconButton(
        tooltip: 'Обновить вкладку',
        onPressed: controller.canRefresh ? controller.refresh : null,
        icon: const Icon(Icons.refresh),
      ),
    );
