import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../log_line.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = MacosTheme.of(context);
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('日志'),
        titleWidth: 72,
        enableBlur: true,
        actions: [
          ToolBarIconButton(
            label: '清空',
            icon: const MacosIcon(CupertinoIcons.trash),
            showLabel: false,
            tooltipMessage: '清空',
            onPressed: state.clearLogs,
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, sc) {
            if (state.logs.isEmpty) {
              return Center(
                child: Text(
                  '还没有记录',
                  style: theme.typography.body.copyWith(
                    color: MacosColors.systemGrayColor,
                  ),
                ),
              );
            }
            return ListView.separated(
              controller: sc,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.logs.length,
              separatorBuilder: (_, _) => Container(
                height: 1,
                color: MacosColors.separatorColor.withValues(alpha: 0.25),
              ),
              itemBuilder: (context, i) => _LogRow(line: state.logs[i]),
            );
          },
        ),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.line});
  final LogLine line;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final color = switch (line.level) {
      LogLevel.error => MacosColors.systemRedColor,
      LogLevel.warn => MacosColors.systemOrangeColor,
      LogLevel.debug => MacosColors.systemGrayColor,
      LogLevel.info => MacosColors.systemGreenColor,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              _hhmmss(line.at),
              style: theme.typography.caption1.copyWith(
                color: MacosColors.systemGrayColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              line.message,
              style: theme.typography.body.copyWith(
                height: 1.35,
                fontFamily: 'Menlo',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hhmmss(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
