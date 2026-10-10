import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_modules.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('crm_module_generator_');
    await File.fromUri(root.uri.resolve('pubspec.yaml'))
        .writeAsString('name: fixture\n');
    await Directory.fromUri(root.uri.resolve('lib/modules/'))
        .create(recursive: true);
  });

  tearDown(() => root.delete(recursive: true));

  Future<void> addModule(String name) async {
    final file = File.fromUri(
      root.uri.resolve('lib/modules/$name/module.dart'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('// Public entrypoint fixture\n');
  }

  test(
    'discovery uses direct entrypoints and deterministic import order',
    () async {
      await addModule('tasks');
      await addModule('customers');
      final privateFile = File.fromUri(
        root.uri.resolve('lib/modules/auth/widgets/module.dart'),
      );
      await privateFile.parent.create(recursive: true);
      await privateFile.writeAsString('// Not a module entrypoint');
      expect(await discoverModules(root), ['customers', 'tasks']);
      final source = generateRegistrySource(await discoverModules(root));
      expect(source, generateRegistrySource(['tasks', 'customers']));
      expect(source, contains("../modules/customers/module.dart' as module0"));
      expect(source, contains('module1.createModule(apiClient)'));
      expect(source, isNot(contains('auth/module.dart')));
    },
  );

  test(
    'new entrypoint is discovered without a manual registration list',
    () async {
      await addModule('customers');
      await generateModuleRegistry(root: root);
      await addModule('warehouse');
      expect(
        await generateModuleRegistry(root: root, check: true),
        GenerationResult.stale,
      );
      expect(
        await generateModuleRegistry(root: root),
        GenerationResult.written,
      );
      final output = await File.fromUri(root.uri.resolve(registryPath))
          .readAsString();
      expect(output, contains('../modules/warehouse/module.dart'));
    },
  );

  test(
    'check is read-only; generation is idempotent and removes old imports',
    () async {
      await addModule('tasks');
      final output = File.fromUri(root.uri.resolve(registryPath));
      expect(
        await generateModuleRegistry(root: root, check: true),
        GenerationResult.stale,
      );
      expect(await output.exists(), isFalse);
      expect(
        await generateModuleRegistry(root: root),
        GenerationResult.written,
      );
      final first = await output.readAsString();
      expect(
        await generateModuleRegistry(root: root),
        GenerationResult.unchanged,
      );
      // Git/Windows line endings do not make the registry stale.
      await output.writeAsString(first.replaceAll('\n', '\r\n'));
      expect(
        await generateModuleRegistry(root: root, check: true),
        GenerationResult.unchanged,
      );
      await File.fromUri(root.uri.resolve('lib/modules/tasks/module.dart'))
          .delete();
      expect(
        await generateModuleRegistry(root: root),
        GenerationResult.written,
      );
      expect(await output.readAsString(), isNot(contains('../modules/tasks/')));
    },
  );

  test('rejects unsafe directory names and duplicates', () {
    for (final name in ['../tasks', 'bad-name', "quote'", 'Upper', '1tasks']) {
      expect(() => generateRegistrySource([name]), throwsFormatException);
    }
    expect(
      () => generateRegistrySource(['tasks', 'tasks']),
      throwsFormatException,
    );
  });

  test(
    'wrong root and a handwritten output fail without overwriting files',
    () async {
      final other = Directory.fromUri(root.uri.resolve('other/'));
      await other.create();
      await expectLater(discoverModules(other), throwsFormatException);
      final output = File.fromUri(root.uri.resolve(registryPath));
      await output.parent.create(recursive: true);
      await output.writeAsString('// Handwritten code');
      await expectLater(
        generateModuleRegistry(root: root),
        throwsFormatException,
      );
      expect(await output.readAsString(), '// Handwritten code');
    },
  );

  test('checked-in project registry is up to date', () async {
    expect(
      await generateModuleRegistry(root: Directory.current, check: true),
      GenerationResult.unchanged,
    );
  });
}
