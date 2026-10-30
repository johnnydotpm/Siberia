import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:siberia_plugins/siberia_plugins.dart';

/// Run from plugins/sdk, optionally pass the /plugins directory.
void main(List<String> args) {
  final root = Directory(args.isEmpty ? '..' : args.single);
  final catalog = parsePluginCatalog(
    jsonDecode(File('${root.path}/catalog.json').readAsStringSync()),
  );
  for (final release in catalog) {
    final file = File('${root.path}/${release.artifact}');
    final metadata = File('${file.parent.path}/manifest.json');
    final stored = PluginManifest.fromJson(
      jsonDecode(metadata.readAsStringSync()),
    );
    if (jsonEncode(stored.toJson()) != jsonEncode(release.toJson()) ||
        file.lengthSync() != release.bytes ||
        sha256.convert(file.readAsBytesSync()).toString() != release.sha256) {
      throw const PluginException('release_mismatch');
    }
  }
  stdout.writeln('Validated ${catalog.length} plugin releases.');
}
