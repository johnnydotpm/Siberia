/// A deliberately small host ABI. Changes require a new API version.
const pluginApiVersion = 1;
const pluginRuntimeVersion = 'dart_eval-0.8.5';
const pluginMaxBytes = 4 * 1024 * 1024;

class PluginException implements Exception {
  const PluginException(this.code);

  /// Stable code only: never include request bodies, tokens or VM stack traces.
  final String code;
  @override
  String toString() => 'PluginException($code)';
}

/// Catalog entries are release manifests. Paths are relative to /plugins/.
class PluginManifest {
  PluginManifest._({
    required this.id,
    required this.name,
    required this.version,
    required this.artifact,
    required this.sha256,
    required this.bytes,
    required this.operations,
    required this.origins,
  });

  final String id;
  final String name;
  final String version;
  final String artifact;
  final String sha256;
  final int bytes;
  final Set<String> operations;

  /// Exact HTTPS origins; no wildcard domains or redirects.
  final Set<String> origins;

  factory PluginManifest.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const PluginException('invalid_manifest');
    }
    String field(String key, RegExp pattern) {
      final entry = value[key];
      if (entry is! String || !pattern.hasMatch(entry)) {
        throw const PluginException('invalid_manifest');
      }
      return entry;
    }

    final id = field('id', RegExp(r'^[a-z][a-z0-9-]{0,63}$'));
    if (const {'librus', 'demo', 'signed-out'}.contains(id)) {
      throw const PluginException('reserved_plugin_id');
    }
    final version = field('version', RegExp(r'^\d{1,7}\.\d{1,7}\.\d{1,7}$'));
    final name = value['name'];
    final bytes = value['bytes'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        bytes is! int ||
        bytes < 1 ||
        bytes > pluginMaxBytes) {
      throw const PluginException('invalid_manifest');
    }
    if (value['apiVersion'] != pluginApiVersion ||
        value['runtime'] != pluginRuntimeVersion) {
      throw const PluginException('incompatible_plugin');
    }
    final artifact = value['artifact'];
    // Canonical paths rule out absolute URLs, traversal and URL escaping.
    if (artifact != '$id/$version/plugin.evc') {
      throw const PluginException('invalid_artifact_path');
    }
    final digest = field('sha256', RegExp(r'^[a-f0-9]{64}$'));
    Set<String> strings(String key) {
      final entries = value[key];
      if (entries is! List ||
          entries.length > 64 ||
          entries.any((entry) => entry is! String)) {
        throw const PluginException('invalid_manifest');
      }
      final result = entries.cast<String>().toSet();
      if (result.length != entries.length) {
        throw const PluginException('invalid_manifest');
      }
      return Set.unmodifiable(result);
    }

    final operations = strings('operations');
    if (operations.isEmpty ||
        operations.any(
          (op) => !RegExp(r'^[a-z][a-zA-Z0-9]{0,63}$').hasMatch(op),
        )) {
      throw const PluginException('invalid_operations');
    }
    final origins = strings('origins');
    for (final origin in origins) {
      final uri = Uri.tryParse(origin);
      if (uri == null || !isPluginHttpsUri(uri) || uri.origin != origin) {
        throw const PluginException('invalid_origin');
      }
    }
    return PluginManifest._(
      id: id,
      name: name,
      version: version,
      artifact: artifact as String,
      sha256: digest,
      bytes: bytes,
      operations: operations,
      origins: origins,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'apiVersion': pluginApiVersion,
    'runtime': pluginRuntimeVersion,
    'artifact': artifact,
    'sha256': sha256,
    'bytes': bytes,
    'operations': operations.toList(),
    'origins': origins.toList(),
  };
}

/// Reject local/ambiguous addresses as well as credentials and fragments.
/// The catalog itself is the trust root, not an arbitrary third-party URL.
bool isPluginHttpsUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    uri.host.isNotEmpty &&
    !uri.hasFragment &&
    uri.port == 443 &&
    uri.host != 'localhost' &&
    !uri.host.endsWith('.localhost') &&
    !RegExp(r'^[\d.]+$').hasMatch(uri.host) &&
    !uri.host.contains(':');

List<PluginManifest> parsePluginCatalog(Object? json) {
  if (json is! Map<String, dynamic> ||
      json['schemaVersion'] != 1 ||
      json['plugins'] is! List) {
    throw const PluginException('invalid_catalog');
  }
  final entries = json['plugins'] as List;
  if (entries.length > 100) throw const PluginException('invalid_catalog');
  final manifests = entries.map(PluginManifest.fromJson).toList();
  if (manifests.map((entry) => entry.id).toSet().length != manifests.length) {
    throw const PluginException('duplicate_plugin');
  }
  return List.unmodifiable(manifests);
}
