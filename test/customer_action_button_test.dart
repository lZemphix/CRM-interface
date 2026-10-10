import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/modules/customers/widgets/customer_details/customer_action_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final primary in [true, false]) {
    testWidgets('header action hover, exit and click (primary=$primary)', (
      tester,
    ) async {
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomerActionButton(
                label: primary ? '+ Задача' : 'Позвонить',
                primary: primary,
                onPressed: () => clicks++,
              ),
            ),
          ),
        ),
      );
      final buttonFinder = find.byType(TextButton);
      Material material() => tester.widget<Material>(
        find
            .descendant(of: buttonFinder, matching: find.byType(Material))
            .first,
      );
      BorderSide side() => (material().shape! as OutlinedBorder).side;
      expect(
        material().color,
        primary ? AppColors.activeElement : Colors.white,
      );
      if (!primary) expect(side().color, AppColors.strongBorder);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(buttonFinder));
      await tester.pumpAndSettle();
      expect(
        material().color,
        primary ? AppColors.activeElementHover : Colors.white,
      );
      if (!primary) expect(side().color, AppColors.textFaint);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        material().color,
        primary ? AppColors.activeElement : Colors.white,
      );
      if (!primary) expect(side().color, AppColors.strongBorder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(clicks, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disabled action cannot fire', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerActionButton(
            label: '+ Задача',
            primary: true,
            onPressed: null,
          ),
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
    expect(
      button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      AppColors.notActiveBorder,
    );
  });
}
