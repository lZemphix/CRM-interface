import 'dart:async';

import 'package:crm_interface/core/api_client/client.dart';
import 'package:crm_interface/core/auth/current_employee_scope.dart';
import 'package:crm_interface/core/modules/module_definition.dart';
import 'package:crm_interface/core/modules/module_registry.dart';
import 'package:crm_interface/core/theme/light/colorscheme.dart';
import 'package:crm_interface/layout/app_shell.dart';
import 'package:crm_interface/modules/auth/auth_session.dart';
import 'package:crm_interface/modules/auth/models/profile.dart';
import 'package:crm_interface/modules/auth/repos/auth.dart';
import 'package:crm_interface/modules/tasks/models/taskboard.dart';
import 'package:crm_interface/modules/tasks/repos/tasks.dart';
import 'package:crm_interface/modules/tasks/screens/tasks.dart';
import 'package:crm_interface/modules/tasks/widgets/task_card.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AuthProfile profile(int id) => AuthProfile(
  id: id,
  login: 'fixture$id',
  fullName: 'Одинаковое имя',
  roleName: 'Тестовая роль',
);

class ProfileRepository extends AuthRepository {
  ProfileRepository(
    super.apiClient,
    super.sessionStore, {
    this.id = 7,
    this.pending,
    this.failure = false,
  });
  int id;
  Completer<AuthProfile>? pending;
  bool failure;
  int reads = 0;
  @override
  Future<AuthProfile> getProfile() {
    reads++;
    if (pending != null) return pending!.future;
    if (failure) {
      return Future.error(const FormatException('Недоступный профиль'));
    }
    return Future.value(profile(id));
  }
}

class BoardRepository extends TasksRepository {
  BoardRepository(super.apiClient);
  int reads = 0;
  @override
  Future<Taskboard> getTaskBoard() async {
    reads++;
    return Taskboard(
      columns: const [
        TaskboardColumn(
          id: '1',
          name: 'Новые',
          order: 0,
          countsAsDone: false,
          status: null,
          version: 1,
        ),
        TaskboardColumn(
          id: '2',
          name: 'Далее',
          order: 1,
          countsAsDone: false,
          status: null,
          version: 1,
        ),
      ],
      tasks: [
        for (final id in [7, 8])
          TaskboardTask(
            id: '$id',
            columnId: '1',
            title: 'Задача $id',
            description: null,
            priority: 'normal',
            responsibleEmployeeId: id,
            responsibleEmployeeName: 'Одинаковое имя',
            version: 1,
            status: 'new',
            subtasks: const [],
          ),
      ],
    );
  }
}

void main() {
  late ApiClient api;
  late BoardRepository board;
  late ModuleRegistry modules;
  setUp(() {
    api = ApiClient(SessionStore());
    board = BoardRepository(api);
    modules = ModuleRegistry([
      ModuleDefinition(
        id: 'tasks',
        title: 'Задачи',
        description: 'Fixture',
        icon: Icons.task_alt,
        screenBuilder: (_) => TasksScreen(tasksRepository: board),
      ),
    ]);
  });
  tearDown(() => api.dio.close(force: true));

  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<AuthRepository> auth,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<AuthRepository>(
          valueListenable: auth,
          builder: (_, repository, _) =>
              AppShell(modules: modules, authRepository: repository),
        ),
      ),
    );
    // An intentionally pending profile keeps the account spinner animated.
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  BoxDecoration decorationFor(WidgetTester tester, int taskId) {
    final card = find.byWidgetPredicate(
      (widget) => widget is TaskCard && widget.task.id == '$taskId',
    );
    return tester
        .widget<AppFlowyGroupCard>(
          find.descendant(of: card, matching: find.byType(AppFlowyGroupCard)),
        )
        .decoration;
  }

  testWidgets(
    'profile arrives without recreating the board or making another profile request',
    (tester) async {
      final pending = Completer<AuthProfile>();
      final repository = ProfileRepository(
        api,
        api.sessionStore,
        pending: pending,
      );
      await mount(tester, ValueNotifier<AuthRepository>(repository));
      final state = tester.state(find.byType(TasksScreen));
      expect(decorationFor(tester, 7).color, AppColors.taskCardBackground);
      pending.complete(profile(7));
      await tester.pumpAndSettle();
      expect(decorationFor(tester, 7).color, AppColors.ownTaskBackground);
      expect(decorationFor(tester, 8).color, AppColors.taskCardBackground);
      expect(tester.state(find.byType(TasksScreen)), same(state));
      expect(repository.reads, 1);
      expect(board.reads, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new or failed profile never retains the previous employee highlight',
    (tester) async {
      final auth = ValueNotifier<AuthRepository>(
        ProfileRepository(api, api.sessionStore),
      );
      await mount(tester, auth);
      final state = tester.state(find.byType(TasksScreen));
      final pending = Completer<AuthProfile>();
      auth.value = ProfileRepository(api, api.sessionStore, pending: pending);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(decorationFor(tester, 7).color, AppColors.taskCardBackground);
      pending.complete(profile(8));
      await tester.pumpAndSettle();
      expect(decorationFor(tester, 8).color, AppColors.ownTaskBackground);
      auth.value = ProfileRepository(api, api.sessionStore, failure: true);
      await tester.pumpAndSettle();
      expect(decorationFor(tester, 8).color, AppColors.taskCardBackground);
      expect(tester.state(find.byType(TasksScreen)), same(state));
      expect(board.reads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'drag preview keeps the explicit viewer ID outside the shell scope',
    (tester) async {
      await mount(
        tester,
        ValueNotifier<AuthRepository>(ProfileRepository(api, api.sessionStore)),
      );
      final origin = tester.getCenter(find.text('Задача 7'));
      final gesture = await tester.startGesture(origin);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveBy(const Offset(70, 20));
      await tester.pump(const Duration(milliseconds: 500));
      final previews = find.byWidgetPredicate(
        (widget) => widget is TaskCard && widget.task.id == '7',
      );
      expect(previews, findsWidgets);
      expect(
        previews.evaluate().any(
          (element) =>
              element.getInheritedWidgetOfExactType<CurrentEmployeeScope>() ==
              null,
        ),
        isTrue,
        reason: 'The drag feedback must be exercised outside the shell identity scope.',
      );
      for (final card in tester.widgetList<TaskCard>(previews)) {
        expect(card.currentEmployeeId, 7);
      }
      expect(find.text('Вам · Одинаковое имя'), findsWidgets);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
