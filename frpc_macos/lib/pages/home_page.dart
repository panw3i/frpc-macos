import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/confirm.dart';
import '../widgets/server_editor.dart';
import '../widgets/tunnel_editor.dart';
import 'dashboard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MacosTabController _tabs = MacosTabController(length: 2);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final server = state.selectedServer;
    return MacosScaffold(
      toolBar: ToolBar(
        title: Text(server?.label ?? '服务'),
        titleWidth: 140,
        enableBlur: true,
        actions: [
          CustomToolbarItem(
            inToolbarBuilder: (context) => MacosSegmentedControl(
              controller: _tabs,
              tabs: const [
                MacosTab(label: '服务'),
                MacosTab(label: '状态'),
              ],
            ),
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, sc) {
            if (server == null) {
              return Center(
                child: Text(
                  '在左侧增加一个服务',
                  style: MacosTheme.of(context).typography.body.copyWith(
                    color: MacosColors.secondaryLabelColor.resolveFrom(context),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _tabBody(state, server),
            );
          },
        ),
      ],
    );
  }

  Widget _tabBody(AppState state, FrpsServer server) {
    if (_tabs.index == 1) {
      return ListView(
        children: [ServerDashboard(serverId: server.id)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ServerForm(server: server),
              _ConnectRow(serverId: server.id),
              if (!state.hasFrpc) ...[
                const SizedBox(height: 12),
                const _FrpcPrep(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TunnelEditor(serverId: server.id, fill: true),
        ),
      ],
    );
  }
}

class _ConnectRow extends StatelessWidget {
  const _ConnectRow({required this.serverId});
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions[serverId];
    final running = session?.running == true;
    final error = session?.error;
    return Row(
      children: [
        PushButton(
          controlSize: ControlSize.regular,
          onPressed: running
              ? () => state.disconnect(serverId)
              : () => state.connect(serverId),
          child: Text(running ? '断开' : '连接'),
        ),
        const SizedBox(width: 14),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              final label = state.serverById(serverId)?.label ?? '这个渠道';
              final ok = await confirmDelete(
                context,
                title: '删除渠道？',
                message: '删除「$label」以及它下面的隧道。',
              );
              if (ok) await state.removeServer(serverId);
            },
            child: Text(
              '删除',
              style: MacosTheme.of(context).typography.body.copyWith(
                color: MacosColors.systemRedColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            error ?? (running ? '已连接' : ''),
            style: MacosTheme.of(context).typography.caption1.copyWith(
              color: error != null
                  ? MacosColors.systemRedColor
                  : MacosColors.secondaryLabelColor.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _FrpcPrep extends StatelessWidget {
  const _FrpcPrep();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.scanningFrpc) {
      return const SizedBox(width: 16, height: 16, child: ProgressCircle());
    }
    return Row(
      children: [
        PushButton(
          controlSize: ControlSize.small,
          secondary: true,
          onPressed: state.discoverLocalFrpc,
          child: const Text('再检查一次'),
        ),
        const SizedBox(width: 8),
        PushButton(
          controlSize: ControlSize.small,
          onPressed: state.loadingReleases || state.downloadStatus != null
              ? null
              : state.downloadLatest,
          child: Text(
            state.downloadStatus ??
                (state.loadingReleases ? '拉取版本…' : '下载最新版'),
          ),
        ),
      ],
    );
  }
}
