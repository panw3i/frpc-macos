import 'dart:convert';
import 'dart:io';

import 'agent_api.dart';
import 'app_state.dart';

const kAgentSockName = 'agent.sock';

AgentServer? runningAgentServer;

class AgentServer {
  AgentServer(this.state);

  final AppState state;
  HttpServer? _server;
  late final AgentApi api = AgentApi(state);

  File? get sockFile {
    final root = state.dataDir;
    if (root == null) return null;
    return File('${root.path}/$kAgentSockName');
  }

  Future<void> start() async {
    await runningAgentServer?.stop();
    runningAgentServer = this;
    final file = sockFile;
    if (file == null) return;
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final server = await HttpServer.bind(
      InternetAddress(file.path, type: InternetAddressType.unix),
      0,
    );
    _server = server;
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {}
    server.listen(_onRequest);
    state.appendLog('agent 控制接口 ${file.path}');
  }

  Future<void> stop() async {
    if (identical(runningAgentServer, this)) {
      runningAgentServer = null;
    }
    final server = _server;
    _server = null;
    await server?.close(force: true);
    final file = sockFile;
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _onRequest(HttpRequest req) async {
    Map<String, dynamic>? body;
    try {
      final raw = await utf8.decoder.bind(req).join();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          body = {'value': decoded};
        }
      }
    } catch (e) {
      await _write(req, 400, {
        'ok': false,
        'error': 'bad_request',
        'message': 'invalid json: $e',
      });
      return;
    }
    final query = <String, String>{};
    req.uri.queryParameters.forEach((k, v) => query[k] = v);
    final result = await api.handle(
      method: req.method,
      path: req.uri.path,
      query: query,
      body: body,
    );
    await _write(req, result.status, result.body);
  }

  Future<void> _write(
    HttpRequest req,
    int status,
    Map<String, dynamic> body,
  ) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(const JsonEncoder.withIndent('  ').convert(body));
    await req.response.close();
  }
}
