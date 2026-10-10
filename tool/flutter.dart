import 'dart:io';

import 'generate_modules.dart';

/// Runs generation before forwarding the command to the installed Flutter SDK.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/flutter.dart <flutter arguments>');
    exitCode = 64;
    return;
  }
  try {
    await generateModuleRegistry(root: Directory.current);
    final bin = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    final sdkFlutter = File.fromUri(
      bin.uri.resolve(Platform.isWindows ? 'flutter.bat' : 'flutter'),
    );
    final process = await Process.start(
      sdkFlutter.existsSync() ? sdkFlutter.path : 'flutter',
      args,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln('Cannot start Flutter: ${error.message}');
    exitCode = 1;
  }
}
