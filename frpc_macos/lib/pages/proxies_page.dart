import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/tunnel_editor.dart';

class ProxiesPage extends StatelessWidget {
  const ProxiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final server = state.selectedServer;
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('隧道'),
        titleWidth: 72,
        actions: [
          ToolBarIconButton(
            label: '添加',
            icon: const MacosIcon(CupertinoIcons.plus),
            showLabel: false,
            tooltipMessage: '增加一条',
            onPressed: () => state.addProxy(serverId: server?.id),
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, sc) {
            if (server == null) {
              return const Center(child: Text('先增加一个服务'));
            }
            return ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                TunnelEditor(serverId: server.id),
              ],
            );
          },
        ),
      ],
    );
  }
}
