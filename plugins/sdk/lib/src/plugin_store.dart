import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'manifest.dart';

/// A verified installed release. Constructed only after validating its bytes.
class InstalledPlugin {
  InstalledPlugin._(this.manifest, Uint8List bytecode)
    : bytecode = bytecode.asUnmodifiableView();
  final PluginManifest manifest;
  final Uint8List bytecode;
}

/// Downloads from this repository only. Applications supply their persistent
/// application-support directory; credentials never belong in this cache.
class PluginStore {
  PluginStore({required this.directory, Dio? client, Uri? source})
    : _client =
          client ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))),
      source = source ?? productionSource {
    if (!isPluginHttpsUri(this.source) ||
        !this.source.path.endsWith('/') ||
        this.source.hasQuery) {
      throw const PluginException('invalid_catalog_source');
    }
  }

  static final productionSource = Uri.parse(
    'https://raw.githubusercontent.com/johnnydotpm/Siberia/main/plugins/',
  );

  final Directory directory;
  final Uri source;
  final Dio _client;
  final _installing = <String, Future<InstalledPlugin>>{};

  Future<Uint8List> _download(Uri uri, int limit) async {
    final cancel = CancelToken();
    Future<Uint8List> receive() async {
      final response = await _client.get<ResponseBody>(
        uri.toString(),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (status) => status == 200,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final body = response.data;
      if (body == null) throw const PluginException('empty_download');
      final builder = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 15),
      )) {
        if (builder.length + chunk.length > limit) {
          throw const PluginException('download_too_large');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    try {
      return await receive().timeout(const Duration(seconds: 45));
    } on PluginException {
      rethrow;
    } on Object {
      throw const PluginException('download_failed');
    } finally {
      cancel.cancel();
    }
  }

  /// Refreshing the catalog is explicit; reading an installed release never
  /// needs a network connection and never silently upgrades its protocol.
  Future<List<PluginManifest>> catalog() async {
    final bytes = await _download(source.resolve('catalog.json'), 256 * 1024);
    try {
      return parsePluginCatalog(jsonDecode(utf8.decode(bytes)));
    } on PluginException {
      rethrow;
    } on Object {
      throw const PluginException('invalid_catalog');
    }
  }

  /// Reuses a verified release offline. Concurrent callers share one download.
  /// A failing new release cannot replace an older installed version.
  Future<InstalledPlugin> install(PluginManifest manifest) {
    final key = '${manifest.id}/${manifest.version}/${manifest.sha256}';
    final pending = _installing[key];
    if (pending != null) return pending;
    final future = _install(manifest);
    _installing[key] = future;
    return future.whenComplete(() => _installing.remove(key));
  }

  File _file(PluginManifest manifest) => File(
    '${directory.path}/${manifest.id}/${manifest.version}/${manifest.sha256}.evc',
  );

  bool _matches(PluginManifest manifest, Uint8List bytes) =>
      bytes.length == manifest.bytes &&
      sha256.convert(bytes).toString() == manifest.sha256;

  Future<InstalledPlugin> _install(PluginManifest manifest) async {
    final file = _file(manifest);
    if (await file.exists() && await file.length() <= pluginMaxBytes) {
      final bytes = await file.readAsBytes();
      if (_matches(manifest, bytes)) return InstalledPlugin._(manifest, bytes);
    }
    final bytes = await _download(
      source.resolve(manifest.artifact),
      manifest.bytes,
    );
    if (!_matches(manifest, bytes)) {
      throw const PluginException('integrity_failed');
    }
    await file.parent.create(recursive: true);
    // Unique staging files support independent foreground/background stores.
    final staging = await file.parent.createTemp('.install-');
    try {
      final temporary = File('${staging.path}/plugin.evc');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
    return InstalledPlugin._(manifest, bytes);
  }
}
