import 'dart:async';

import 'package:crm_interface/core/widgets/section_refresh_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refresh joins all registered blocks and ignores duplicate requests',
    () async {
      final controller = SectionRefreshController();
      addTearDown(controller.dispose);
      final first = Completer<void>();
      final second = Completer<void>();
      var calls = 0;
      controller.attach(
        'first',
        refresh: () {
          calls++;
          return first.future;
        },
        busy: () => false,
      );
      controller.attach(
        'second',
        refresh: () {
          calls++;
          return second.future;
        },
        busy: () => false,
      );
      final pending = controller.refresh();
      expect(controller.isBusy, isTrue);
      await controller.refresh();
      expect(calls, 2);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.isBusy, isTrue);
      second.complete();
      await pending;
      expect(controller.canRefresh, isTrue);
    },
  );

  test(
    'busy block prevents refresh; detaching or failure does not leave a lock',
    () async {
      final controller = SectionRefreshController();
      addTearDown(controller.dispose);
      var saving = true;
      var calls = 0;
      controller.attach(
        'note',
        refresh: () async {
          calls++;
          throw const FormatException('bad response');
        },
        busy: () => saving,
      );
      await controller.refresh();
      expect(calls, 0);
      saving = false;
      await expectLater(controller.refresh(), throwsFormatException);
      expect(controller.canRefresh, isTrue);
      controller.detach('note');
      expect(controller.canRefresh, isFalse);
    },
  );
}
