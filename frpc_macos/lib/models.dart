class AppSettings {
  AppSettings({
    this.logLevel = 'info',
    this.autoConnect = false,
  });

  String logLevel;
  bool autoConnect;

  Map<String, dynamic> toJson() => {
    'logLevel': logLevel,
    'autoConnect': autoConnect,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    logLevel: json['logLevel'] as String? ?? 'info',
    autoConnect: json['autoConnect'] as bool? ?? false,
  );
}

class FrpsServer {
  FrpsServer({
    required this.id,
    this.name = '',
    this.addr = '',
    this.port = 7000,
    this.token = '',
    this.user = '',
    List<ProxyItem>? proxies,
  }) : proxies = proxies ?? [];

  String id;
  String name;
  String addr;
  int port;
  String token;
  String user;
  List<ProxyItem> proxies;

  bool get ready => addr.trim().isNotEmpty && token.trim().isNotEmpty;

  bool get hasTunnel => proxies.any((p) {
    if (!p.enabled || p.localPort <= 0) return false;
    if (p.type == 'http' || p.type == 'https') {
      return p.customDomains.any((d) => d.trim().isNotEmpty) ||
          p.subdomain.trim().isNotEmpty;
    }
    return p.remotePort > 0;
  });

  String get label {
    final n = name.trim();
    if (n.isNotEmpty) return n;
    if (addr.trim().isEmpty) return '未命名';
    return '$addr:$port';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'addr': addr,
    'port': port,
    'token': token,
    'user': user,
    'proxies': proxies.map((p) => p.toJson()).toList(),
  };

  factory FrpsServer.fromJson(Map<String, dynamic> json) => FrpsServer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    addr: json['addr'] as String? ?? json['serverAddr'] as String? ?? '',
    port: json['port'] as int? ?? json['serverPort'] as int? ?? 7000,
    token: json['token'] as String? ?? '',
    user: json['user'] as String? ?? '',
    proxies: (json['proxies'] as List? ?? [])
        .map((e) => ProxyItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ProxyItem {
  ProxyItem({
    required this.id,
    required this.name,
    this.type = 'tcp',
    this.localIp = '127.0.0.1',
    this.localPort = 8888,
    this.remotePort = 16888,
    this.customDomains = const [],
    this.subdomain = '',
    this.enabled = true,
  });

  String id;
  String name;
  String type;
  String localIp;
  int localPort;
  int remotePort;
  List<String> customDomains;
  String subdomain;
  bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'localIp': localIp,
    'localPort': localPort,
    'remotePort': remotePort,
    'customDomains': customDomains,
    'subdomain': subdomain,
    'enabled': enabled,
  };

  factory ProxyItem.fromJson(Map<String, dynamic> json) => ProxyItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'proxy',
    type: json['type'] as String? ?? 'tcp',
    localIp: json['localIp'] as String? ?? '127.0.0.1',
    localPort: json['localPort'] as int? ?? 8888,
    remotePort: json['remotePort'] as int? ?? 16888,
    customDomains: (json['customDomains'] as List?)?.cast<String>() ?? const [],
    subdomain: json['subdomain'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
}

class FrpRelease {
  FrpRelease({
    required this.tag,
    required this.assetName,
    required this.url,
    this.localPath,
  });

  final String tag;
  final String assetName;
  final String url;
  String? localPath;

  bool get downloaded => localPath != null && localPath!.isNotEmpty;
}
