import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frpc_macos/frpc_lookup.dart';
import 'package:frpc_macos/log_line.dart';
import 'package:frpc_macos/models.dart';
import 'package:frpc_macos/stats.dart';
import 'package:frpc_macos/toml.dart';

void main() {
  test('generateFrpcToml writes token auth and enabled tcp proxy', () {
    final toml = generateFrpcToml(
      FrpsServer(
        id: 's1',
        addr: 'frps.example.com',
        port: 7000,
        token: 'secret',
        user: 'alice',
      ),
      [
        ProxyItem(
          id: '1',
          name: 'ssh',
          type: 'tcp',
          localIp: '127.0.0.1',
          localPort: 22,
          remotePort: 6000,
        ),
        ProxyItem(
          id: '2',
          name: 'off',
          enabled: false,
        ),
      ],
    );
    expect(toml, contains('serverAddr = "frps.example.com"'));
    expect(toml, contains('serverPort = 7000'));
    expect(toml, contains('user = "alice"'));
    expect(toml, contains('token = "secret"'));
    expect(toml, contains('name = "ssh"'));
    expect(toml, contains('remotePort = 6000'));
    expect(toml, isNot(contains('name = "off"')));
  });

  test('empty proxy name falls back to type-port, not web', () {
    final toml = generateFrpcToml(
      FrpsServer(id: 's1', addr: '1.2.3.4', token: 't'),
      [ProxyItem(id: '1', name: '', type: 'tcp', localPort: 8888, remotePort: 16888)],
    );
    expect(toml, contains('name = "tcp-8888"'));
    expect(toml, isNot(contains('name = "web"')));
  });

  test('FrpsServer nests proxies and migrates old global list', () {
    final nested = FrpsServer.fromJson({
      'id': 'oracle',
      'name': 'oracle',
      'addr': '1.2.3.4',
      'port': 7000,
      'token': 't',
      'proxies': [
        {'id': 'p1', 'name': 'web', 'localPort': 8888, 'remotePort': 16888},
      ],
    });
    expect(nested.proxies.single.name, 'web');
    expect(nested.hasTunnel, isTrue);
    final httpOnly = FrpsServer(
      id: 's2',
      addr: '1.2.3.4',
      token: 't',
      proxies: [
        ProxyItem(
          id: 'h',
          name: 'site',
          type: 'http',
          localPort: 8080,
          remotePort: 0,
          customDomains: ['app.example.com'],
        ),
      ],
    );
    expect(httpOnly.hasTunnel, isTrue);

    final legacy = FrpsServer.fromJson({
      'id': 's1',
      'addr': '1.2.3.4',
      'token': 't',
    });
    expect(legacy.proxies, isEmpty);
  });

  test('generateFrpcToml quotes special characters', () {
    expect(quote(r'a"b'), r'"a\"b"');
  });

  test('formatBytes and parseClientStatus', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    final proxies = parseClientStatus(
      '{"tcp":[{"name":"web","type":"tcp","status":"running","err":"","local_addr":"127.0.0.1:8888","remote_addr":"1.2.3.4:16888"}]}',
    );
    expect(proxies.single.name, 'web');
    expect(proxies.single.online, isTrue);
    final info = parseServerInfo(
      '{"totalTrafficIn":2048,"totalTrafficOut":4096,"curConns":2,"clientCounts":1}',
    );
    expect(info.trafficIn, 2048);
    expect(info.conns, 2);
  });

  test('LogLine.parse strips ansi and frp file location', () {
    const raw =
        '\x1B[1;34m2026-10-03 14:08:25.002 [I] [client/service.go:332] [4df3014581179d88] login to server success, get run id [4df3014581179d88]\x1B[0m';
    final line = LogLine.parse(raw);
    expect(line.message, '已登录服务器');
    expect(line.level, LogLevel.info);
    expect(line.message.contains('\x1B'), isFalse);
    expect(line.message.contains('[1;34m'), isFalse);
  });

  test('findLocalFrpc picks frpc under extraDir', () async {
    final dir = await Directory.systemTemp.createTemp('frpc-lookup-');
    final nested = Directory('${dir.path}/v0.1');
    await nested.create();
    final bin = File('${nested.path}/frpc');
    await bin.writeAsString('#!/bin/sh\n');
    final hits = await findLocalFrpc(extraDir: dir.path);
    expect(hits, contains(bin.absolute.path));
    await dir.delete(recursive: true);
  });
}
