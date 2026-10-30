import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:siberia_plugins/siberia_plugins.dart';

/// `dart run tool/package_plugin.dart <source directory> <release directory>`
/// The source directory contains plugin.json and src/main.dart (package:diary).
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: package_plugin.dart <source> <release>');
    exitCode = 64;
    return;
  }
  try {
    final source = Directory(args[0]);
    final output = Directory(args[1]);
    final descriptor =
        jsonDecode(File('${source.path}/plugin.json').readAsStringSync())
            as Map<String, dynamic>;
    final src = Directory('${source.path}/src');
    final files = <String, String>{};
    for (final file in src.listSync(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('.dart')) {
        final relative = file.path
            .substring(src.path.length + 1)
            .replaceAll('\\', '/');
        files[relative] = file.readAsStringSync();
      }
    }
    if (!files.containsKey('main.dart')) {
      throw const PluginException('missing_entrypoint');
    }
    final bytes = Uint8List.fromList(
      Compiler().compile({'diary': files}).write(),
    );
    final manifest = PluginManifest.fromJson({
      ...descriptor,
      'apiVersion': pluginApiVersion,
      'runtime': pluginRuntimeVersion,
      'artifact': '${descriptor['id']}/${descriptor['version']}/plugin.evc',
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
    });
    final artifact = File('${output.path}/plugin.evc');
    final metadata = File('${output.path}/manifest.json');
    if (artifact.existsSync() || metadata.existsSync()) {
      throw const PluginException('release_already_exists');
    }
    output.createSync(recursive: true);
    artifact.writeAsBytesSync(bytes, flush: true);
    metadata.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
      flush: true,
    );
    stdout.writeln(
      '${manifest.id} ${manifest.version}: ${manifest.bytes} bytes',
    );
  } on Object {
    // Inputs may include private fixtures: do not print compiler diagnostics.
    stderr.writeln(
      'Plugin packaging failed. Check metadata, source and output.',
    );
    exitCode = 1;
  }
}
