import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/bootstrap/modules.g.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/core/theme/app_palette.dart';
import 'package:crm_interface/main.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/auth/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openApp(WidgetTester tester) async {
  final session = SessionStore();
  final api = ApiClient(session);
  addTearDown(() => api.dio.close(force: true));
  await tester.pumpWidget(
    MyApp(
      authRepository: AuthRepository(api, session),
      modules: createModuleRegistry(api),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('backgrounds and elevated surfaces use neutral semantic colors', (
    tester,
  ) async {
    await openApp(tester);
    final theme = Theme.of(tester.element(find.byType(AuthScreen)));
    final scheme = theme.colorScheme;
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.canvasColor, AppColors.background);
    expect(scheme.surface, AppPalette.light.surface);
    expect(scheme.surfaceBright, AppPalette.light.surface);
    expect(scheme.surfaceContainer, AppPalette.light.surface);
    expect([
      scheme.surfaceDim,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
    ], everyElement(AppColors.background));
    expect([
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ], everyElement(AppPalette.light.surfaceMuted));
    expect(scheme.surfaceTint, Colors.transparent);

    final canvas = tester
        .widgetList<Material>(find.byType(Material))
        .firstWhere((material) => material.type == MaterialType.canvas);
    expect(canvas.color, AppColors.background);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'default dialogs do not restore the generated purple background',
    (tester) async {
      await openApp(tester);
      final dialog = showDialog<void>(
        context: tester.element(find.byType(AuthScreen)),
        builder: (_) => const AlertDialog(title: Text('Проверка фона')),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surface.color, AppPalette.light.surface);
      expect(surface.surfaceTintColor, Colors.transparent);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await dialog;
      expect(tester.takeException(), isNull);
    },
  );
}
