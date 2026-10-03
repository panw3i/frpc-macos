import 'models.dart';

String quote(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

/// Generate frpc.toml for fatedier/frp v0.52+ (proxies array).
const int kFrpcAdminPort = 17400;

String generateFrpcToml(
  FrpsServer server,
  List<ProxyItem> proxies, {
  String logLevel = 'info',
  int adminPort = kFrpcAdminPort,
}) {
  final buf = StringBuffer();
  buf.writeln('serverAddr = ${quote(server.addr)}');
  buf.writeln('serverPort = ${server.port}');
  if (server.user.trim().isNotEmpty) {
    buf.writeln('user = ${quote(server.user.trim())}');
  }
  buf.writeln();
  buf.writeln('[auth]');
  buf.writeln('method = "token"');
  buf.writeln('token = ${quote(server.token)}');
  buf.writeln();
  buf.writeln('[log]');
  buf.writeln('to = "console"');
  buf.writeln('level = ${quote(logLevel)}');
  buf.writeln();
  buf.writeln('[webServer]');
  buf.writeln('addr = "127.0.0.1"');
  buf.writeln('port = $adminPort');
  buf.writeln();

  for (final proxy in proxies.where((p) => p.enabled)) {
    buf.writeln('[[proxies]]');
    final name = proxy.name.trim().isEmpty
        ? '${proxy.type}-${proxy.localPort}'
        : proxy.name.trim();
    buf.writeln('name = ${quote(name)}');
    buf.writeln('type = ${quote(proxy.type)}');
    buf.writeln('localIP = ${quote(proxy.localIp)}');
    buf.writeln('localPort = ${proxy.localPort}');
    if (proxy.type == 'tcp' || proxy.type == 'udp') {
      buf.writeln('remotePort = ${proxy.remotePort}');
    }
    if (proxy.type == 'http' || proxy.type == 'https') {
      final domains = proxy.customDomains
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();
      if (domains.isNotEmpty) {
        buf.writeln(
          'customDomains = [${domains.map(quote).join(', ')}]',
        );
      }
      if (proxy.subdomain.trim().isNotEmpty) {
        buf.writeln('subdomain = ${quote(proxy.subdomain.trim())}');
      }
    }
    buf.writeln();
  }
  return buf.toString();
}
