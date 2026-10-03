import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'frpc_lookup.dart';
import 'log_line.dart';
import 'models.dart';
import 'stats.dart';
import 'toml.dart';

class ServerSession {
  ServerSession({this.adminPort = kFrpcAdminPort});

  Process? process;
  StreamSubscription<String>? stdoutSub;
  StreamSubscription<String>? stderrSub;
  int adminPort;
  LiveStats stats = LiveStats();
  String? error;
  DateTime? lastStartTime;
  bool running = false;
}

class AppState extends ChangeNotifier {
  AppSettings settings = AppSettings();
  List<FrpsServer> servers = [];
  List<FrpRelease> releases = [];
  List<LogLine> logs = [];
  String? selectedFrpcPath;
  String? selectedServerId;
  bool loadingReleases = false;
  bool scanningFrpc = true;
  String? downloadStatus;
  List<String> localFrpcHits = [];
  String bundledVersion = '';
  final Map<String, ServerSession> sessions = {};

  Directory? _root;
  Timer? _statsTimer;

  Directory? get dataDir => _root;

  ServerSession sessionOf(String id) =>
      sessions.putIfAbsent(id, ServerSession.new);

  FrpsServer? serverById(String id) {
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  FrpsServer? get selectedServer {
    final current = selectedServerId;
    if (current != null) {
      final s = serverById(current);
      if (s != null) return s;
    }
    return servers.isEmpty ? null : servers.first;
  }

  bool get running => sessions.values.any((s) => s.running);

  int get connectedCount =>
      sessions.values.where((s) => s.running).length;

  String? get connectionError {
    for (final s in sessions.values) {
      if (s.running && s.error != null) return s.error;
    }
    for (final s in sessions.values) {
      if (s.error != null) return s.error;
    }
    return null;
  }

  bool get hasFrpc =>
      selectedFrpcPath != null && File(selectedFrpcPath!).existsSync();

  bool get hasServer => servers.any((s) => s.ready);

  bool get hasTunnel => servers.any((s) => s.hasTunnel);

  Future<void> downloadLatest() async {
    if (releases.isEmpty) {
      await refreshReleases();
    }
    if (releases.isEmpty) return;
    for (final r in releases) {
      if (r.downloaded && r.localPath != null) {
        await useFrpc(r.localPath!);
        return;
      }
    }
    await downloadRelease(releases.first);
  }

  Future<void> load() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory('${support.path}/FrpcDesktop');
    await _root!.create(recursive: true);
    await Directory('${_root!.path}/bin').create(recursive: true);
    final file = File('${_root!.path}/config.json');
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final rawSettings = json['settings'] as Map<String, dynamic>? ?? {};
      settings = AppSettings.fromJson(rawSettings);
      servers = (json['servers'] as List? ?? [])
          .map((e) => FrpsServer.fromJson(e as Map<String, dynamic>))
          .toList();
      if (servers.isEmpty) {
        final addr = rawSettings['serverAddr'] as String? ?? '';
        final token = rawSettings['token'] as String? ?? '';
        if (addr.isNotEmpty || token.isNotEmpty) {
          servers = [
            FrpsServer(
              id: 'oracle',
              name: 'oracle',
              addr: addr,
              port: rawSettings['serverPort'] as int? ?? 7000,
              token: token,
              user: rawSettings['user'] as String? ?? '',
            ),
          ];
        }
      }
      final globalProxies = (json['proxies'] as List? ?? [])
          .map((e) => ProxyItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (globalProxies.isNotEmpty &&
          servers.isNotEmpty &&
          servers.every((s) => s.proxies.isEmpty)) {
        servers.first.proxies = globalProxies;
      }
      selectedFrpcPath = json['selectedFrpcPath'] as String?;
      selectedServerId = json['selectedServerId'] as String?;
    }
    if (servers.isEmpty) {
      servers = [
        FrpsServer(
          id: 's1',
          name: '服务',
          proxies: [_newProxy()],
        ),
      ];
    }
    if (selectedServerId == null || serverById(selectedServerId!) == null) {
      selectedServerId = servers.first.id;
    }
    _restoreDownloadedBins();
    appendLog('数据目录 ${_root!.path}');
    await installBundledFrpc();
    if (!hasFrpc) {
      await discoverLocalFrpc();
    }
    scanningFrpc = false;
    notifyListeners();
    if (settings.autoConnect) {
      unawaited(connect());
    }
  }

  Future<void> installBundledFrpc() async {
    try {
      bundledVersion = (await rootBundle.loadString('assets/frpc/VERSION')).trim();
    } catch (_) {
      bundledVersion = 'bundled';
    }
    if (bundledVersion.isEmpty) bundledVersion = 'bundled';
    final dir = Directory('${_root!.path}/bin/$bundledVersion');
    final out = File('${dir.path}/frpc');
    final stamp = File('${dir.path}/.asset');
    final needCopy = !out.existsSync() ||
        !stamp.existsSync() ||
        (await stamp.readAsString()).trim() != bundledVersion;
    if (needCopy) {
      final data = await rootBundle.load('assets/frpc/frpc');
      await dir.create(recursive: true);
      await out.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await Process.run('chmod', ['+x', out.path]);
      await stamp.writeAsString(bundledVersion);
    }
    selectedFrpcPath = out.path;
    await save();
    appendLog('使用内置 frpc $bundledVersion');
  }

  Future<void> discoverLocalFrpc() async {
    scanningFrpc = true;
    notifyListeners();
    final hits = await findLocalFrpc(extraDir: '${_root!.path}/bin');
    localFrpcHits = hits;
    final current = selectedFrpcPath;
    final currentOk = current != null && File(current).existsSync();
    if (!currentOk && hits.isNotEmpty) {
      selectedFrpcPath = hits.first;
      await save();
      appendLog('使用本机 frpc $selectedFrpcPath');
    } else if (currentOk) {
      appendLog('使用 frpc $current');
    } else {
      appendLog('本机未找到 frpc');
    }
    scanningFrpc = false;
    notifyListeners();
  }

  void _restoreDownloadedBins() {
    final bin = Directory('${_root!.path}/bin');
    if (!bin.existsSync()) return;
    for (final dir in bin.listSync().whereType<Directory>()) {
      final frpc = File('${dir.path}/frpc');
      if (frpc.existsSync()) {
        final tag = dir.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        releases.removeWhere((r) => r.tag == tag);
        releases.add(
          FrpRelease(
            tag: tag,
            assetName: 'frpc',
            url: '',
            localPath: frpc.path,
          ),
        );
        selectedFrpcPath ??= frpc.path;
      }
    }
  }

  Future<void> save() async {
    final root = _root;
    if (root == null) return;
    final file = File('${root.path}/config.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'settings': settings.toJson(),
        'servers': servers.map((s) => s.toJson()).toList(),
        'selectedServerId': selectedServerId,
        'selectedFrpcPath': selectedFrpcPath,
      }),
    );
  }

  void appendLog(String text) {
    for (final line in text.split('\n')) {
      final parsed = LogLine.parse(line);
      if (parsed.message.isEmpty) continue;
      logs.add(parsed);
    }
    if (logs.length > 2000) {
      logs = logs.sublist(logs.length - 1500);
    }
    notifyListeners();
  }

  void _appendSessionLog(String serverId, String text) {
    final label = serverById(serverId)?.label ?? serverId;
    for (final line in text.split('\n')) {
      final parsed = LogLine.parse(line);
      if (parsed.message.isEmpty) continue;
      logs.add(
        LogLine(
          at: parsed.at,
          message: '$label  ${parsed.message}',
          level: parsed.level,
        ),
      );
    }
    if (logs.length > 2000) {
      logs = logs.sublist(logs.length - 1500);
    }
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  Future<void> updateSettings(void Function(AppSettings s) fn) async {
    fn(settings);
    await save();
    notifyListeners();
  }

  ProxyItem _newProxy({String? name, FrpsServer? server}) {
    final all = [for (final s in servers) ...s.proxies];
    final usedLocal = {for (final p in all) p.localPort};
    var local = 8888;
    while (usedLocal.contains(local)) {
      local++;
    }
    final usedRemote = {for (final p in server?.proxies ?? const <ProxyItem>[]) p.remotePort};
    var remote = 16888;
    while (usedRemote.contains(remote) || remote < 16000) {
      remote++;
    }
    if (remote > 16999) remote = 16000;
    return ProxyItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name ?? '',
      type: 'tcp',
      localPort: local,
      remotePort: remote,
    );
  }

  Future<FrpsServer> addServer({
    String? name,
    String? addr,
    int? port,
    String? token,
    String? user,
    bool defaultTunnel = true,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final server = FrpsServer(
      id: id,
      name: name ?? (servers.isEmpty ? '服务' : '服务-${servers.length + 1}'),
      addr: addr ?? '',
      port: port ?? 7000,
      token: token ?? '',
      user: user ?? '',
    );
    if (defaultTunnel) {
      server.proxies.add(_newProxy(server: server));
    }
    servers.add(server);
    selectedServerId = id;
    await save();
    notifyListeners();
    return server;
  }

  Future<void> selectServer(String id) async {
    if (selectedServerId == id) return;
    selectedServerId = id;
    await save();
    notifyListeners();
  }

  Future<void> removeServer(String id) async {
    await disconnect(id);
    servers.removeWhere((s) => s.id == id);
    sessions.remove(id);
    if (selectedServerId == id) {
      selectedServerId = servers.isEmpty ? null : servers.first.id;
    }
    if (servers.isEmpty) {
      await addServer();
      return;
    }
    await save();
    notifyListeners();
  }

  Future<void> updateServerById(String id, void Function(FrpsServer s) fn) async {
    final s = serverById(id);
    if (s == null) return;
    fn(s);
    await save();
    notifyListeners();
  }

  Future<ProxyItem?> addProxy({
    String? serverId,
    String? name,
    String? type,
    String? localIp,
    int? localPort,
    int? remotePort,
    List<String>? customDomains,
    String? subdomain,
    bool? enabled,
  }) async {
    var server = serverId == null ? selectedServer : serverById(serverId);
    server ??= await addServer();
    final proxy = _newProxy(name: name, server: server);
    if (type != null) proxy.type = type;
    if (localIp != null) proxy.localIp = localIp;
    if (localPort != null) proxy.localPort = localPort;
    if (remotePort != null) proxy.remotePort = remotePort;
    if (customDomains != null) proxy.customDomains = customDomains;
    if (subdomain != null) proxy.subdomain = subdomain;
    if (enabled != null) proxy.enabled = enabled;
    server.proxies.add(proxy);
    await save();
    notifyListeners();
    await _reloadIfRunning(server.id);
    return proxy;
  }

  Future<void> removeProxy(String proxyId, {String? serverId}) async {
    FrpsServer? server;
    if (serverId != null) {
      server = serverById(serverId);
    } else {
      for (final s in servers) {
        if (s.proxies.any((p) => p.id == proxyId)) {
          server = s;
          break;
        }
      }
    }
    if (server == null) return;
    server.proxies.removeWhere((p) => p.id == proxyId);
    await save();
    notifyListeners();
    await _reloadIfRunning(server.id);
  }

  Future<void> updateProxyById(
    String proxyId,
    void Function(ProxyItem p) fn, {
    String? serverId,
  }) async {
    Iterable<FrpsServer> scope = servers;
    if (serverId != null) {
      final s = serverById(serverId);
      if (s == null) return;
      scope = [s];
    }
    FrpsServer? owner;
    for (final s in scope) {
      for (final p in s.proxies) {
        if (p.id == proxyId) {
          fn(p);
          owner = s;
          break;
        }
      }
      if (owner != null) break;
    }
    if (owner == null) return;
    await save();
    notifyListeners();
    await _reloadIfRunning(owner.id);
  }

  Future<void> moveProxy(String proxyId, String toServerId) async {
    FrpsServer? from;
    ProxyItem? proxy;
    for (final s in servers) {
      for (final p in s.proxies) {
        if (p.id == proxyId) {
          from = s;
          proxy = p;
          break;
        }
      }
      if (from != null) break;
    }
    if (from == null || proxy == null || from.id == toServerId) return;
    final to = serverById(toServerId);
    if (to == null) return;
    from.proxies.removeWhere((p) => p.id == proxyId);
    to.proxies.add(proxy);
    await save();
    notifyListeners();
    await _reloadIfRunning(from.id);
    await _reloadIfRunning(to.id);
  }

  Future<void> _reloadIfRunning(String serverId) async {
    final session = sessions[serverId];
    final server = serverById(serverId);
    if (session == null || !session.running || server == null) return;
    try {
      await _writeToml(server, session.adminPort);
      await http
          .get(Uri.parse('http://127.0.0.1:${session.adminPort}/api/reload'))
          .timeout(const Duration(seconds: 2));
      _appendSessionLog(serverId, '已重新加载隧道');
    } catch (_) {}
  }

  Future<void> useFrpc(String path) async {
    selectedFrpcPath = path;
    await save();
    notifyListeners();
  }

  Future<File> _writeToml(FrpsServer server, int adminPort) async {
    final file = File('${_root!.path}/frpc-${server.id}.toml');
    await file.writeAsString(
      generateFrpcToml(
        server,
        server.proxies,
        logLevel: settings.logLevel,
        adminPort: adminPort,
      ),
    );
    return file;
  }

  int _allocAdminPort() {
    final used = {
      for (final s in sessions.values)
        if (s.running) s.adminPort,
    };
    var port = kFrpcAdminPort;
    while (used.contains(port)) {
      port++;
    }
    return port;
  }

  /// Connect one server, or every ready disconnected server when [serverId] is null.
  Future<void> connect([String? serverId]) async {
    if (serverId != null) {
      await _connectOne(serverId);
      return;
    }
    for (final s in List<FrpsServer>.from(servers)) {
      if (s.ready && sessions[s.id]?.running != true) {
        await _connectOne(s.id);
      }
    }
  }

  Future<void> _connectOne(String serverId) async {
    final existing = sessions[serverId];
    if (existing?.running == true) return;
    final server = serverById(serverId);
    if (server == null || !server.ready) {
      final session = sessionOf(serverId);
      session.error = '请先填写这台 frps 的地址和 token';
      _appendSessionLog(serverId, session.error!);
      notifyListeners();
      return;
    }
    final bin = selectedFrpcPath;
    if (bin == null || !File(bin).existsSync()) {
      final session = sessionOf(serverId);
      session.error = '请先准备 frpc';
      _appendSessionLog(serverId, session.error!);
      notifyListeners();
      return;
    }
    final session = sessionOf(serverId);
    session.adminPort = _allocAdminPort();
    final toml = await _writeToml(server, session.adminPort);
    session.error = null;
    _appendSessionLog(serverId, '正在启动 frpc');
    try {
      session.process = await Process.start(bin, ['-c', toml.path]);
    } catch (e) {
      session.error = '$e';
      _appendSessionLog(serverId, '启动失败 $e');
      notifyListeners();
      return;
    }
    session.running = true;
    session.lastStartTime = DateTime.now();
    session.stats = LiveStats();
    _ensureStatsPolling();
    notifyListeners();
    final process = session.process!;
    session.stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _onFrpcLine(serverId, line));
    session.stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _onFrpcLine(serverId, line));
    unawaited(
      process.exitCode.then((code) {
        final current = sessions[serverId];
        if (current == null || current.process != process) return;
        current.running = false;
        current.process = null;
        _stopStatsPollingIfIdle();
        _appendSessionLog(serverId, 'frpc 退出 code=$code');
        if (current.error == null && code != 0) {
          current.error = 'frpc 退出 $code';
        }
        notifyListeners();
      }),
    );
  }

  void _onFrpcLine(String serverId, String line) {
    _appendSessionLog(serverId, line);
    final session = sessions[serverId];
    if (session == null) return;
    final parsed = LogLine.parse(line);
    final lower = parsed.message.toLowerCase();
    if (lower.contains('已登录') ||
        lower.contains('已启动') ||
        line.toLowerCase().contains('login to server success') ||
        line.toLowerCase().contains('start proxy success')) {
      session.error = null;
    }
    if (line.toLowerCase().contains('connect to server error') ||
        line.toLowerCase().contains('login to server failed')) {
      session.error = parsed.message;
    }
    notifyListeners();
  }

  /// Disconnect one server, or every connected server when [serverId] is null.
  Future<void> disconnect([String? serverId]) async {
    if (serverId != null) {
      await _disconnectOne(serverId);
      return;
    }
    for (final id in List<String>.from(sessions.keys)) {
      await _disconnectOne(id);
    }
  }

  Future<void> _disconnectOne(String serverId) async {
    final session = sessions[serverId];
    if (session == null) return;
    final p = session.process;
    session.process = null;
    await session.stdoutSub?.cancel();
    await session.stderrSub?.cancel();
    session.stdoutSub = null;
    session.stderrSub = null;
    if (p != null) {
      p.kill();
      try {
        await p.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        p.kill(ProcessSignal.sigkill);
      }
    }
    session.running = false;
    _stopStatsPollingIfIdle();
    if (p != null) {
      _appendSessionLog(serverId, '已断开');
    }
    notifyListeners();
  }

  void _ensureStatsPolling() {
    _statsTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(refreshStats());
    });
    unawaited(refreshStats());
  }

  void _stopStatsPollingIfIdle() {
    if (running) return;
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> refreshStats() async {
    var changed = false;
    for (final server in servers) {
      final session = sessions[server.id];
      if (session == null || !session.running) continue;
      await _refreshSession(server, session);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _refreshSession(FrpsServer server, ServerSession session) async {
    var proxiesLive = <ProxyLive>[];
    try {
      final local = await http
          .get(Uri.parse('http://127.0.0.1:${session.adminPort}/api/status'))
          .timeout(const Duration(seconds: 1));
      if (local.statusCode == 200) {
        proxiesLive = parseClientStatus(local.body);
      }
    } catch (_) {}

    var trafficIn = session.stats.trafficIn;
    var trafficOut = session.stats.trafficOut;
    var conns = session.stats.conns;
    var clients = session.stats.clients;
    try {
      final auth =
          'Basic ${base64Encode(utf8.encode('admin:${server.token}'))}';
      final headers = {'Authorization': auth, 'User-Agent': 'frpc-macos'};
      final info = await http
          .get(
            Uri.parse('http://${server.addr}:17500/api/serverinfo'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 1));
      if (info.statusCode == 200) {
        final s = parseServerInfo(info.body);
        trafficIn = s.trafficIn;
        trafficOut = s.trafficOut;
        conns = s.conns;
        clients = s.clients;
      }
      final types = {for (final p in proxiesLive) p.type};
      if (types.isEmpty) types.add('tcp');
      for (final type in types) {
        try {
          final px = await http
              .get(
                Uri.parse('http://${server.addr}:17500/api/proxy/$type'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 1));
          if (px.statusCode == 200) {
            proxiesLive = parseServerProxies(px.body, proxiesLive);
          }
        } catch (_) {}
      }
    } catch (_) {}

    session.stats = mergeStats(
      previous: session.stats,
      fromClient: proxiesLive,
      trafficIn: trafficIn,
      trafficOut: trafficOut,
      conns: conns,
      clients: clients,
    );
  }

  String _hostArch() {
    try {
      final r = Process.runSync('uname', ['-m']);
      final m = (r.stdout as String).trim();
      if (m == 'x86_64') return 'amd64';
      return 'arm64';
    } catch (_) {
      return 'arm64';
    }
  }

  Future<void> refreshReleases() async {
    loadingReleases = true;
    notifyListeners();
    final arch = _hostArch();
    try {
      final res = await http.get(
        Uri.parse(
          'https://api.github.com/repos/fatedier/frp/releases?per_page=12',
        ),
        headers: {
          'User-Agent': 'frpc-macos',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (res.statusCode != 200) {
        throw Exception('GitHub ${res.statusCode}: ${res.body}');
      }
      final list = jsonDecode(res.body) as List;
      final next = <FrpRelease>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final tag = map['tag_name'] as String? ?? '';
        final assets = map['assets'] as List? ?? [];
        Map<String, dynamic>? asset;
        for (final a in assets) {
          final name = (a as Map<String, dynamic>)['name'] as String? ?? '';
          if (name.contains('darwin') &&
              name.contains(arch) &&
              name.endsWith('.tar.gz')) {
            asset = a;
            break;
          }
        }
        if (asset == null) continue;
        final local = File('${_root!.path}/bin/$tag/frpc');
        next.add(
          FrpRelease(
            tag: tag,
            assetName: asset['name'] as String,
            url: asset['browser_download_url'] as String,
            localPath: local.existsSync() ? local.path : null,
          ),
        );
      }
      releases = next;
      if (selectedFrpcPath == null) {
        final ready = releases.where((r) => r.downloaded).toList();
        if (ready.isNotEmpty) selectedFrpcPath = ready.first.localPath;
      }
      appendLog('已刷新 ${releases.length} 个 darwin/$arch 版本');
    } catch (e) {
      appendLog('刷新版本失败 $e');
    } finally {
      loadingReleases = false;
      notifyListeners();
    }
  }

  Future<void> downloadRelease(FrpRelease release) async {
    downloadStatus = '下载 ${release.assetName}';
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse(release.url),
        headers: {'User-Agent': 'frpc-macos'},
      );
      if (res.statusCode != 200) {
        throw Exception('download ${res.statusCode}');
      }
      downloadStatus = '解压 ${release.tag}';
      notifyListeners();
      final tarBytes = GZipDecoder().decodeBytes(res.bodyBytes);
      final tar = TarDecoder().decodeBytes(tarBytes);
      ArchiveFile? frpcFile;
      for (final f in tar) {
        final name = f.name.replaceAll('\\', '/');
        if (name.endsWith('/frpc') || name == 'frpc') {
          frpcFile = f;
          break;
        }
      }
      if (frpcFile == null || frpcFile.size <= 0) {
        throw Exception('压缩包里没有 frpc');
      }
      final dir = Directory('${_root!.path}/bin/${release.tag}');
      await dir.create(recursive: true);
      final out = File('${dir.path}/frpc');
      await out.writeAsBytes(frpcFile.content as List<int>);
      await Process.run('chmod', ['+x', out.path]);
      release.localPath = out.path;
      selectedFrpcPath = out.path;
      await save();
      appendLog('已安装 ${release.tag} -> ${out.path}');
    } catch (e) {
      appendLog('下载失败 $e');
    } finally {
      downloadStatus = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
