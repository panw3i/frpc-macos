import 'dart:io';

/// 本机常见 frpc 位置。先 PATH / Homebrew / ~/.local，再应用自己下过的副本。
Future<List<String>> findLocalFrpc({String? extraDir}) async {
  final hits = <String>[];

  void consider(String? path) {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final abs = file.absolute.path;
    if (hits.contains(abs)) return;
    hits.add(abs);
  }

  final home = Platform.environment['HOME'] ?? '';
  for (final path in [
    if (home.isNotEmpty) '$home/.local/bin/frpc',
    if (home.isNotEmpty) '$home/bin/frpc',
    '/opt/homebrew/bin/frpc',
    '/opt/homebrew/opt/frp/bin/frpc',
    '/usr/local/bin/frpc',
    '/usr/local/opt/frp/bin/frpc',
  ]) {
    consider(path);
  }

  try {
    final which = await Process.run('/bin/zsh', ['-lc', 'command -v frpc']);
    if (which.exitCode == 0) {
      consider((which.stdout as String).trim().split('\n').first);
    }
  } catch (_) {}

  if (extraDir != null) {
    final bin = Directory(extraDir);
    if (bin.existsSync()) {
      for (final dir in bin.listSync().whereType<Directory>()) {
        consider('${dir.path}/frpc');
      }
    }
  }

  return hits;
}
