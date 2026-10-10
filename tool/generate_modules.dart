import 'dart:io';

const registryPath = 'lib/bootstrap/modules.g.dart';
const generatedHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND.';

enum GenerationResult { written, unchanged, stale }

/// Only discovers public entrypoints: it never executes or parses module code.
Future<List<String>> discoverModules(Directory root) async {
  final modules = Directory.fromUri(root.uri.resolve('lib/modules/'));
  if (!File.fromUri(root.uri.resolve('pubspec.yaml')).existsSync() ||
      !modules.existsSync()) {
    throw const FormatException('Run from the Flutter project root');
  }
  final names = <String>[];
  await for (final entity in modules.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final entrypoint = File.fromUri(entity.uri.resolve('module.dart'));
    if (await FileSystemEntity.type(entrypoint.path, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    names.add(entity.uri.pathSegments.where((part) => part.isNotEmpty).last);
  }
  names.sort();
  return names;
}

String generateRegistrySource(Iterable<String> moduleNames) {
  final names = moduleNames.toList()..sort();
  final unique = <String>{};
  for (final name in names) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw FormatException('Invalid module directory name: $name');
    }
    if (!unique.add(name)) {
      throw FormatException('Duplicate module directory: $name');
    }
  }
  final source = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln('// Run: dart run tool/generate_modules.dart')
    ..writeln()
    ..writeln("import '../core/api_client/client.dart';")
    ..writeln("import '../core/modules/module_registry.dart';");
  for (var i = 0; i < names.length; i++) {
    source.writeln("import '../modules/${names[i]}/module.dart' as module$i;");
  }
  source
    ..writeln()
    ..writeln('ModuleRegistry createModuleRegistry(ApiClient apiClient) {');
  if (names.isEmpty) {
    source
      ..writeln('  return ModuleRegistry([]);')
      ..writeln('}');
    return source.toString();
  }
  source.writeln('  return ModuleRegistry([');
  for (var i = 0; i < names.length; i++) {
    source.writeln('    module$i.createModule(apiClient),');
  }
  source
    ..writeln('  ]);')
    ..writeln('}');
  return source.toString();
}

Future<GenerationResult> generateModuleRegistry({
  required Directory root,
  bool check = false,
}) async {
  final source = generateRegistrySource(await discoverModules(root));
  final output = File.fromUri(root.uri.resolve(registryPath));
  final previous = await output.exists() ? await output.readAsString() : null;
  if (previous?.replaceAll('\r\n', '\n') == source) {
    return GenerationResult.unchanged;
  }
  if (check) return GenerationResult.stale;
  if (previous != null && !previous.startsWith(generatedHeader)) {
    throw const FormatException(
      'Refusing to overwrite a non-generated registry',
    );
  }
  await output.parent.create(recursive: true);
  await output.writeAsString(source, flush: true);
  return GenerationResult.written;
}

Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln('Usage: dart run tool/generate_modules.dart [--check]');
    exitCode = 64;
    return;
  }
  try {
    final result = await generateModuleRegistry(
      root: Directory.current,
      check: args.contains('--check'),
    );
    if (result == GenerationResult.stale) {
      stderr.writeln(
        'Module registry is stale. Run dart run tool/generate_modules.dart',
      );
      exitCode = 1;
    } else {
      stdout.writeln('Module registry: ${result.name}');
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Cannot generate module registry: ${error.message}');
    exitCode = 1;
  }
}
