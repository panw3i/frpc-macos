import 'package:flutter_test/flutter_test.dart';
import 'package:frpc_macos/agent_api.dart';
import 'package:frpc_macos/app_state.dart';
import 'package:frpc_macos/models.dart';

void main() {
  test('agent snapshot lists nested tunnels and connection flags', () async {
    final state = AppState();
    state.servers = [
      FrpsServer(
        id: 's1',
        name: 'oracle',
        addr: '1.2.3.4',
        token: 'secret',
        proxies: [
          ProxyItem(
            id: 'p1',
            name: 'site',
            localPort: 8888,
            remotePort: 16888,
          ),
        ],
      ),
    ];
    state.selectedServerId = 's1';
    final api = AgentApi(state);
    final res = await api.handle(method: 'GET', path: '/v1/status');
    expect(res.status, 200);
    expect(res.body['ok'], isTrue);
    expect(res.body['servers'], isNotEmpty);
    final server = (res.body['servers'] as List).first as Map;
    expect(server['name'], 'oracle');
    expect(server['connected'], isFalse);
    expect(server['token'], 'secret');
    expect((server['proxies'] as List).single['name'], 'site');
  });

  test('agent can add and patch a channel without a dummy tunnel', () async {
    final state = AppState();
    final api = AgentApi(state);
    final created = await api.handle(
      method: 'POST',
      path: '/v1/servers',
      body: {
        'name': 'oracle',
        'addr': '213.35.120.5',
        'port': 7000,
        'token': 'tok',
      },
    );
    expect(created.status, 200);
    final server = created.body['server'] as Map;
    expect(server['name'], 'oracle');
    expect(server['proxies'], isEmpty);
    final id = server['id'] as String;

    final patched = await api.handle(
      method: 'PATCH',
      path: '/v1/servers/$id',
      body: {'name': 'prod'},
    );
    expect(patched.body['server']['name'], 'prod');
    expect(state.serverById(id)!.name, 'prod');
  });

  test('agent adds a tcp tunnel under a channel', () async {
    final state = AppState();
    state.servers = [
      FrpsServer(id: 's1', name: 'svc', addr: '1.2.3.4', token: 't'),
    ];
    final api = AgentApi(state);
    final res = await api.handle(
      method: 'POST',
      path: '/v1/tunnels',
      body: {
        'server': 's1',
        'name': 'web',
        'type': 'tcp',
        'localPort': 8888,
        'remotePort': 16888,
      },
    );
    expect(res.status, 200, reason: '${res.body}');
    expect(res.body['tunnel']['name'], 'web');
    expect(res.body['tunnel']['localPort'], 8888);
    expect(state.servers.single.proxies.single.remotePort, 16888);
  });

  test('unknown route is 404 json', () async {
    final api = AgentApi(AppState());
    final res = await api.handle(method: 'GET', path: '/v1/nope');
    expect(res.status, 404);
    expect(res.body['ok'], isFalse);
  });
}
