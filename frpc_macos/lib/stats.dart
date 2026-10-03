import 'dart:convert';
import 'dart:math' as math;

class ProxyLive {
  ProxyLive({
    required this.name,
    required this.type,
    required this.status,
    this.localAddr = '',
    this.remoteAddr = '',
    this.err = '',
    this.trafficIn = 0,
    this.trafficOut = 0,
    this.conns = 0,
  });

  final String name;
  final String type;
  final String status;
  final String localAddr;
  final String remoteAddr;
  final String err;
  final int trafficIn;
  final int trafficOut;
  final int conns;

  bool get online =>
      status == 'running' || status == 'online' || status == 'start proxy success';
}

class LiveStats {
  LiveStats({
    this.trafficIn = 0,
    this.trafficOut = 0,
    this.conns = 0,
    this.clients = 0,
    this.inRate = 0,
    this.outRate = 0,
    this.proxies = const [],
    List<double>? inHistory,
    List<double>? outHistory,
    this.updatedAt,
  }) : inHistory = inHistory ?? [],
       outHistory = outHistory ?? [];

  final int trafficIn;
  final int trafficOut;
  final int conns;
  final int clients;
  final int inRate;
  final int outRate;
  final List<ProxyLive> proxies;
  final List<double> inHistory;
  final List<double> outHistory;
  final DateTime? updatedAt;

  int get tunnelsOnline => proxies.where((p) => p.online).length;
}

String formatBytes(int n) {
  if (n < 0) n = 0;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final digits = i == 0 ? 0 : 1;
  return '${v.toStringAsFixed(digits)} ${units[i]}';
}

String formatRate(int bytesPerSec) => '${formatBytes(bytesPerSec)}/s';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

LiveStats mergeStats({
  required LiveStats previous,
  required List<ProxyLive> fromClient,
  int trafficIn = 0,
  int trafficOut = 0,
  int conns = 0,
  int clients = 0,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  var inRate = 0;
  var outRate = 0;
  if (previous.updatedAt != null) {
    final dt = t.difference(previous.updatedAt!).inMilliseconds / 1000.0;
    if (dt > 0.2) {
      inRate = math.max(0, ((trafficIn - previous.trafficIn) / dt).round());
      outRate = math.max(0, ((trafficOut - previous.trafficOut) / dt).round());
    }
  }
  final inHist = [...previous.inHistory, inRate.toDouble()];
  final outHist = [...previous.outHistory, outRate.toDouble()];
  while (inHist.length > 60) {
    inHist.removeAt(0);
  }
  while (outHist.length > 60) {
    outHist.removeAt(0);
  }

  return LiveStats(
    trafficIn: trafficIn,
    trafficOut: trafficOut,
    conns: conns,
    clients: clients,
    inRate: inRate,
    outRate: outRate,
    proxies: fromClient,
    inHistory: inHist,
    outHistory: outHist,
    updatedAt: t,
  );
}

List<ProxyLive> parseClientStatus(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return [];
  final out = <ProxyLive>[];
  for (final entry in decoded.entries) {
    final list = entry.value;
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map) continue;
      out.add(
        ProxyLive(
          name: '${item['name'] ?? ''}',
          type: '${item['type'] ?? entry.key}',
          status: '${item['status'] ?? ''}',
          localAddr: '${item['local_addr'] ?? ''}',
          remoteAddr: '${item['remote_addr'] ?? ''}',
          err: '${item['err'] ?? ''}',
        ),
      );
    }
  }
  return out;
}

({int trafficIn, int trafficOut, int conns, int clients}) parseServerInfo(
  String body,
) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    return (trafficIn: 0, trafficOut: 0, conns: 0, clients: 0);
  }
  int asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  return (
    trafficIn: asInt(decoded['totalTrafficIn']),
    trafficOut: asInt(decoded['totalTrafficOut']),
    conns: asInt(decoded['curConns']),
    clients: asInt(decoded['clientCounts']),
  );
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

List<ProxyLive> parseServerProxies(String body, List<ProxyLive> base) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return base;
  final list = decoded['proxies'];
  if (list is! List) return base;
  final extra = <String, Map>{};
  for (final item in list) {
    if (item is Map && item['name'] != null) {
      extra['${item['name']}'] = Map<String, dynamic>.from(item);
    }
  }
  if (base.isEmpty) {
    return [
      for (final e in extra.values)
        ProxyLive(
          name: '${e['name']}',
          type: '${e['type'] ?? ''}',
          status: '${e['status'] ?? ''}',
          trafficIn: _asInt(e['todayTrafficIn']),
          trafficOut: _asInt(e['todayTrafficOut']),
          conns: _asInt(e['curConns']),
        ),
    ];
  }
  return [
    for (final p in base)
      ProxyLive(
        name: p.name,
        type: p.type,
        status: p.status,
        localAddr: p.localAddr,
        remoteAddr: p.remoteAddr,
        err: p.err,
        trafficIn: extra[p.name] != null
            ? _asInt(extra[p.name]!['todayTrafficIn'])
            : p.trafficIn,
        trafficOut: extra[p.name] != null
            ? _asInt(extra[p.name]!['todayTrafficOut'])
            : p.trafficOut,
        conns: extra[p.name] != null
            ? _asInt(extra[p.name]!['curConns'])
            : p.conns,
      ),
  ];
}
