enum LogLevel { debug, info, warn, error }

class LogLine {
  LogLine({
    required this.at,
    required this.message,
    this.level = LogLevel.info,
  });

  final DateTime at;
  final String message;
  final LogLevel level;

  factory LogLine.parse(String raw, {DateTime? at}) {
    final text = stripAnsi(raw);
    return LogLine(
      at: at ?? DateTime.now(),
      message: _humanMessage(text),
      level: _levelOf(text),
    );
  }
}

final _ansi = RegExp(
  r'\x1B\[[0-9;?]*[ -/]*[@-~]|\x1B[@-Z\\-_]|[\x00-\x08\x0B\x0C\x0E-\x1F]',
);

String stripAnsi(String input) {
  return input.replaceAll(_ansi, '').replaceAll('\r', '').trim();
}

LogLevel _levelOf(String text) {
  if (text.contains('[E]') ||
      text.toLowerCase().contains('error') ||
      text.contains('失败')) {
    return LogLevel.error;
  }
  if (text.contains('[W]') || text.toLowerCase().contains('warn')) {
    return LogLevel.warn;
  }
  if (text.contains('[D]') || text.contains('[T]')) {
    return LogLevel.debug;
  }
  return LogLevel.info;
}

String _humanMessage(String text) {
  var msg = text;
  msg = msg.replaceFirst(
    RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?\s*'),
    '',
  );
  msg = msg.replaceFirst(RegExp(r'^\[[IWEDT]\]\s*'), '');
  msg = msg.replaceAll(RegExp(r'\[[\w./\\-]+:\d+\]\s*'), '');
  msg = msg.replaceFirst(RegExp(r'^\[[0-9a-fA-F]{6,}\]\s*'), '');
  msg = msg.replaceFirst(
    RegExp(r'^start frpc service for config file \[.*?\] with aggregated configuration$'),
    '正在读取配置',
  );
  msg = msg.replaceFirst('try to connect to server...', '正在连接服务器');
  msg = msg.replaceFirst(
    RegExp(r'^login to server success.*'),
    '已登录服务器',
  );
  msg = msg.replaceFirstMapped(
    RegExp(r'^proxy added:\s*\[(.+)\]$'),
    (m) => '已添加隧道 ${m[1]}',
  );
  msg = msg.replaceFirstMapped(
    RegExp(r'^\[(.+)\] start proxy success$'),
    (m) => '隧道 ${m[1]} 已启动',
  );
  return msg.trim();
}
