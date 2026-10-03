import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../stats.dart';
import '../widgets/group.dart';

class ServerDashboard extends StatelessWidget {
  const ServerDashboard({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = MacosTheme.of(context);
    final session = state.sessions[serverId];
    final stats = session?.stats ?? LiveStats();
    final running = session?.running == true;
    final uptime = session?.lastStartTime == null || !running
        ? Duration.zero
        : DateTime.now().difference(session!.lastStartTime!);
    final secondary = MacosColors.secondaryLabelColor.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: running ? '运行 ${formatDuration(uptime)}' : '状态',
          dividerIndent: 16,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '下行',
                    value: formatBytes(stats.trafficIn),
                    hint: formatRate(stats.inRate),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '上行',
                    value: formatBytes(stats.trafficOut),
                    hint: formatRate(stats.outRate),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '连接',
                    value: '${stats.conns}',
                    hint: '${stats.clients} 客户端',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '隧道',
                    value: '${stats.tunnelsOnline}',
                    hint: '在线',
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 64,
              child: _Sparkline(
                inbound: stats.inHistory,
                outbound: stats.outHistory,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '隧道',
          dividerIndent: 16,
          children: [
            if (stats.proxies.isEmpty)
              Text(
                running ? '等待隧道状态…' : '连接后显示流量',
                style: theme.typography.body.copyWith(color: secondary),
              )
            else ...[
              const _TunnelHeader(),
              for (final p in stats.proxies) _TunnelRow(proxy: p),
            ],
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final secondary = MacosColors.secondaryLabelColor.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.caption1.copyWith(color: secondary)),
          const SizedBox(height: 2),
          Text(value, style: theme.typography.title2),
          Text(hint, style: theme.typography.caption1.copyWith(color: secondary)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.inbound, required this.outbound});
  final List<double> inbound;
  final List<double> outbound;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(
        inbound: inbound,
        outbound: outbound,
        inColor: MacosColors.systemBlueColor.resolveFrom(context),
        outColor: MacosColors.systemGreenColor.resolveFrom(context),
        grid: MacosColors.separatorColor.withValues(alpha: 0.25),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.inbound,
    required this.outbound,
    required this.inColor,
    required this.outColor,
    required this.grid,
  });

  final List<double> inbound;
  final List<double> outbound;
  final Color inColor;
  final Color outColor;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = [1.0, ...inbound, ...outbound].reduce(math.max);
    final paintGrid = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }
    _line(canvas, size, inbound, inColor, maxY);
    _line(canvas, size, outbound, outColor, maxY);
  }

  void _line(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxY,
  ) {
    if (data.length < 2) return;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - (data[i] / maxY) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.inbound != inbound || old.outbound != outbound;
}

class _TunnelHeader extends StatelessWidget {
  const _TunnelHeader();

  @override
  Widget build(BuildContext context) {
    final style = MacosTheme.of(context).typography.caption1.copyWith(
      color: MacosColors.secondaryLabelColor.resolveFrom(context),
    );
    return Row(
      children: [
        Expanded(flex: 2, child: Text('名称', style: style)),
        Expanded(child: Text('状态', style: style)),
        Expanded(child: Text('连接', style: style)),
        Expanded(child: Text('下行', style: style)),
        Expanded(child: Text('上行', style: style)),
      ],
    );
  }
}

class _TunnelRow extends StatelessWidget {
  const _TunnelRow({required this.proxy});
  final ProxyLive proxy;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final secondary = MacosColors.secondaryLabelColor.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proxy.name, style: theme.typography.body),
                Text(
                  proxy.localAddr.isEmpty
                      ? proxy.remoteAddr
                      : '${proxy.localAddr}  →  ${proxy.remoteAddr}',
                  style: theme.typography.caption1.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              proxy.online ? '在线' : (proxy.status.isEmpty ? '—' : proxy.status),
              style: theme.typography.body.copyWith(
                color: proxy.online
                    ? MacosColors.systemGreenColor
                    : secondary,
              ),
            ),
          ),
          Expanded(child: Text('${proxy.conns}')),
          Expanded(child: Text(formatBytes(proxy.trafficIn))),
          Expanded(child: Text(formatBytes(proxy.trafficOut))),
        ],
      ),
    );
  }
}
