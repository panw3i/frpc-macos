import 'app_state.dart';
import 'log_line.dart';
import 'models.dart';
import 'stats.dart';

class AgentResult {
  AgentResult({
    required this.status,
    required this.body,
  });

  final int status;
  final Map<String, dynamic> body;
}

class AgentApi {
  AgentApi(this.state);

  final AppState state;
  Future<void> _queue = Future.value();

  Future<AgentResult> handle({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
  }) {
    final result = _queue.then(
      (_) => _handle(method, path, query, body ?? const {}),
    );
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<AgentResult> _handle(
    String method,
    String path,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) async {
    final route = _match(method.toUpperCase(), path);
    if (route == null) {
      return _err(404, 'not_found', 'unknown $method $path');
    }
    try {
      return await route(query, body);
    } on FormatException catch (e) {
      return _err(400, 'bad_request', e.message);
    } catch (e) {
      return _err(500, 'error', '$e');
    }
  }

  Future<AgentResult> Function(
    Map<String, String> query,
    Map<String, dynamic> body,
  )?
  _match(String method, String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty || parts.first != 'v1') return null;

    if (method == 'GET' && (_is(parts, ['v1', 'help']) || _is(parts, ['v1']))) {
      return (_, _) async => _ok({'help': help});
    }
    if (method == 'GET' && _is(parts, ['v1', 'status'])) {
      return (_, _) async => _ok(snapshot());
    }
    if (method == 'GET' && _is(parts, ['v1', 'servers'])) {
      return (_, _) async => _ok({
        'servers': [for (final s in state.servers) _serverJson(s)],
      });
    }
    if (method == 'POST' && _is(parts, ['v1', 'servers'])) {
      return (_, body) => _addServer(body);
    }
    if (method == 'POST' && _is(parts, ['v1', 'connect'])) {
      return (_, body) async {
        await state.connect(_string(body['id']));
        return _ok(snapshot());
      };
    }
    if (method == 'POST' && _is(parts, ['v1', 'disconnect'])) {
      return (_, body) async {
        await state.disconnect(_string(body['id']));
        return _ok(snapshot());
      };
    }
    if (method == 'GET' && _is(parts, ['v1', 'tunnels'])) {
      return (query, _) async {
        final id = query['server'];
        final servers = id == null
            ? state.servers
            : [
                if (state.serverById(id) != null) state.serverById(id)!,
              ];
        if (id != null && servers.isEmpty) {
          return _err(404, 'not_found', 'server $id');
        }
        return _ok({
          'tunnels': [
            for (final s in servers)
              for (final p in s.proxies) _proxyJson(s, p),
          ],
        });
      };
    }
    if (method == 'POST' && _is(parts, ['v1', 'tunnels'])) {
      return (_, body) => _addTunnel(body);
    }
    if (method == 'GET' && _is(parts, ['v1', 'logs'])) {
      return (query, _) async {
        var lines = List<LogLine>.from(state.logs);
        final server = query['server'];
        if (server != null && server.isNotEmpty) {
          final label = state.serverById(server)?.label ?? server;
          lines = [
            for (final line in lines)
              if (line.message.startsWith('$label  ') ||
                  line.message.contains(server))
                line,
          ];
        }
        final tail = int.tryParse(query['tail'] ?? '') ?? 100;
        if (tail >= 0 && lines.length > tail) {
          lines = lines.sublist(lines.length - tail);
        }
        return _ok({
          'logs': [
            for (final line in lines)
              {
                'at': line.at.toIso8601String(),
                'level': line.level.name,
                'message': line.message,
              },
          ],
        });
      };
    }
    if (method == 'POST' && _is(parts, ['v1', 'logs', 'clear'])) {
      return (_, _) async {
        state.clearLogs();
        return _ok({'cleared': true});
      };
    }

    if (parts.length >= 3 && parts[1] == 'servers') {
      final id = parts[2];
      if (method == 'GET' && parts.length == 3) {
        return (_, _) async {
          final s = state.serverById(id);
          if (s == null) return _err(404, 'not_found', 'server $id');
          return _ok({'server': _serverJson(s)});
        };
      }
      if (method == 'PATCH' && parts.length == 3) {
        return (_, body) => _patchServer(id, body);
      }
      if (method == 'DELETE' && parts.length == 3) {
        return (_, _) async {
          if (state.serverById(id) == null) {
            return _err(404, 'not_found', 'server $id');
          }
          await state.removeServer(id);
          return _ok(snapshot());
        };
      }
      if (method == 'POST' && _is(parts, ['v1', 'servers', id, 'connect'])) {
        return (_, _) async {
          if (state.serverById(id) == null) {
            return _err(404, 'not_found', 'server $id');
          }
          await state.connect(id);
          return _ok(snapshot());
        };
      }
      if (method == 'POST' && _is(parts, ['v1', 'servers', id, 'disconnect'])) {
        return (_, _) async {
          await state.disconnect(id);
          return _ok(snapshot());
        };
      }
      if (method == 'POST' && _is(parts, ['v1', 'servers', id, 'select'])) {
        return (_, _) async {
          if (state.serverById(id) == null) {
            return _err(404, 'not_found', 'server $id');
          }
          await state.selectServer(id);
          return _ok(snapshot());
        };
      }
    }

    if (parts.length == 3 && parts[1] == 'tunnels') {
      final id = parts[2];
      if (method == 'PATCH') {
        return (_, body) => _patchTunnel(id, body);
      }
      if (method == 'DELETE') {
        return (_, _) async {
          final found = _findProxy(id);
          if (found == null) return _err(404, 'not_found', 'tunnel $id');
          await state.removeProxy(id);
          return _ok(snapshot());
        };
      }
    }
    return null;
  }

  Future<AgentResult> _addServer(Map<String, dynamic> body) async {
    final server = await state.addServer(
      name: _string(body['name']),
      addr: _string(body['addr']),
      port: _int(body['port']),
      token: _string(body['token']),
      user: _string(body['user']),
      defaultTunnel: body['defaultTunnel'] == true,
    );
    return _ok({'server': _serverJson(server)});
  }

  Future<AgentResult> _patchServer(
    String id,
    Map<String, dynamic> body,
  ) async {
    final server = state.serverById(id);
    if (server == null) return _err(404, 'not_found', 'server $id');
    await state.updateServerById(id, (s) {
      final name = _string(body['name']);
      final addr = _string(body['addr']);
      final port = _int(body['port']);
      final token = _string(body['token']);
      final user = _string(body['user']);
      if (name != null) s.name = name;
      if (addr != null) s.addr = addr;
      if (port != null) s.port = port;
      if (token != null) s.token = token;
      if (user != null) s.user = user;
    });
    if (state.sessions[id]?.running == true) {
      await state.disconnect(id);
      await state.connect(id);
    }
    return _ok({'server': _serverJson(state.serverById(id)!)});
  }

  Future<AgentResult> _addTunnel(Map<String, dynamic> body) async {
    final serverId = _string(body['server'] ?? body['serverId']);
    if (serverId == null || state.serverById(serverId) == null) {
      return _err(400, 'bad_request', 'server is required');
    }
    final domains = body['customDomains'] ?? body['domain'];
    List<String>? customDomains;
    String? subdomain;
    if (domains is List) {
      customDomains = [for (final d in domains) '$d'];
    } else if (domains is String && domains.trim().isNotEmpty) {
      if (domains.contains('.')) {
        customDomains = [domains.trim()];
      } else {
        subdomain = domains.trim();
      }
    }
    final proxy = await state.addProxy(
      serverId: serverId,
      name: _string(body['name']),
      type: _string(body['type']),
      localIp: _string(body['localIp']),
      localPort: _int(body['localPort'] ?? body['local']),
      remotePort: _int(body['remotePort'] ?? body['remote']),
      customDomains: customDomains,
      subdomain: subdomain ?? _string(body['subdomain']),
      enabled: _bool(body['enabled']),
    );
    return _ok({'tunnel': _proxyJson(state.serverById(serverId)!, proxy!)});
  }

  Future<AgentResult> _patchTunnel(
    String id,
    Map<String, dynamic> body,
  ) async {
    if (_findProxy(id) == null) {
      return _err(404, 'not_found', 'tunnel $id');
    }
    await state.updateProxyById(id, (p) {
      final name = _string(body['name']);
      final type = _string(body['type']);
      final localIp = _string(body['localIp']);
      final localPort = _int(body['localPort'] ?? body['local']);
      final remotePort = _int(body['remotePort'] ?? body['remote']);
      final subdomain = _string(body['subdomain']);
      final enabled = _bool(body['enabled']);
      if (name != null) p.name = name;
      if (type != null) p.type = type;
      if (localIp != null) p.localIp = localIp;
      if (localPort != null) p.localPort = localPort;
      if (remotePort != null) p.remotePort = remotePort;
      if (subdomain != null) p.subdomain = subdomain;
      if (enabled != null) p.enabled = enabled;
      final domains = body['customDomains'] ?? body['domain'];
      if (domains is List) {
        p.customDomains = [for (final d in domains) '$d'];
      } else if (domains is String) {
        p.customDomains = domains.contains('.') ? [domains] : [];
        if (!domains.contains('.') && p.subdomain.isEmpty) {
          p.subdomain = domains;
        }
      }
    });
    final found = _findProxy(id)!;
    return _ok({'tunnel': _proxyJson(found.$1, found.$2)});
  }

  (FrpsServer, ProxyItem)? _findProxy(String id) {
    for (final s in state.servers) {
      for (final p in s.proxies) {
        if (p.id == id) return (s, p);
      }
    }
    return null;
  }

  Map<String, dynamic> snapshot() {
    return {
      'app': true,
      'dataDir': state.dataDir?.path,
      'frpc': state.selectedFrpcPath,
      'bundledVersion': state.bundledVersion,
      'selectedServerId': state.selectedServerId,
      'connectedCount': state.connectedCount,
      'servers': [for (final s in state.servers) _serverJson(s)],
    };
  }

  Map<String, dynamic> _serverJson(FrpsServer s) {
    final session = state.sessions[s.id];
    final stats = session?.stats ?? LiveStats();
    ProxyLive? liveFor(ProxyItem p) {
      final name = p.name.trim().isEmpty
          ? '${p.type}-${p.localPort}'
          : p.name.trim();
      for (final live in stats.proxies) {
        if (live.name == name || live.name == p.name) return live;
      }
      return null;
    }

    return {
      'id': s.id,
      'name': s.name,
      'label': s.label,
      'addr': s.addr,
      'port': s.port,
      'token': s.token,
      'user': s.user,
      'ready': s.ready,
      'connected': session?.running == true,
      'adminPort': session?.adminPort,
      'error': session?.error,
      'startedAt': session?.lastStartTime?.toIso8601String(),
      'stats': {
        'trafficIn': stats.trafficIn,
        'trafficOut': stats.trafficOut,
        'conns': stats.conns,
        'clients': stats.clients,
        'inRate': stats.inRate,
        'outRate': stats.outRate,
        'tunnelsOnline': stats.tunnelsOnline,
      },
      'proxies': [for (final p in s.proxies) _proxyJson(s, p, liveFor(p))],
    };
  }

  Map<String, dynamic> _proxyJson(
    FrpsServer server,
    ProxyItem p, [
    ProxyLive? live,
  ]) {
    return {
      'id': p.id,
      'serverId': server.id,
      'server': server.label,
      'name': p.name,
      'type': p.type,
      'localIp': p.localIp,
      'localPort': p.localPort,
      'remotePort': p.remotePort,
      'customDomains': p.customDomains,
      'subdomain': p.subdomain,
      'enabled': p.enabled,
      'status': live?.status,
      'localAddr': live?.localAddr,
      'remoteAddr': live?.remoteAddr,
      'err': live?.err,
    };
  }

  static const help = {
    'status': 'GET /v1/status',
    'servers': 'GET /v1/servers',
    'server add': 'POST /v1/servers {name,addr,port,token,user}',
    'server update': 'PATCH /v1/servers/:id',
    'server rm': 'DELETE /v1/servers/:id',
    'connect': 'POST /v1/servers/:id/connect or POST /v1/connect',
    'disconnect': 'POST /v1/servers/:id/disconnect or POST /v1/disconnect',
    'tunnels': 'GET /v1/tunnels?server=',
    'tunnel add':
        'POST /v1/tunnels {server,name,type,localPort,remotePort,domain}',
    'tunnel update': 'PATCH /v1/tunnels/:id',
    'tunnel rm': 'DELETE /v1/tunnels/:id',
    'logs': 'GET /v1/logs?tail=100&server=',
  };

  static bool _is(List<String> parts, List<String> want) {
    if (parts.length != want.length) return false;
    for (var i = 0; i < want.length; i++) {
      if (parts[i] != want[i]) return false;
    }
    return true;
  }

  static AgentResult _ok(Map<String, dynamic> data) => AgentResult(
    status: 200,
    body: {'ok': true, ...data},
  );

  static AgentResult _err(int status, String code, String message) =>
      AgentResult(
        status: status,
        body: {'ok': false, 'error': code, 'message': message},
      );

  static String? _string(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Object? v) {
    if (v == null || v == '') return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  static bool? _bool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = '$v'.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }
}
