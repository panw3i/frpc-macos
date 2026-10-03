import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class VersionsPage extends StatelessWidget {
  const VersionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MacosScaffold(
      toolBar: ToolBar(
        title: const Text('版本'),
        titleWidth: 80,
        actions: [
          ToolBarIconButton(
            label: '刷新',
            icon: const MacosIcon(CupertinoIcons.refresh),
            showLabel: true,
            onPressed: state.loadingReleases ? null : state.refreshReleases,
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, sc) {
            if (state.loadingReleases && state.releases.isEmpty) {
              return const Center(child: ProgressCircle());
            }
            return ListView(
              controller: sc,
              padding: const EdgeInsets.all(20),
              children: [
                if (state.downloadStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(state.downloadStatus!),
                  ),
                if (state.releases.isEmpty)
                  const Text('点工具栏「刷新」从 GitHub 拉取 fatedier/frp 的 darwin 包。'),
                for (final r in state.releases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MacosColors.separatorColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.tag, style: MacosTheme.of(context).typography.title2),
                                  Text(r.assetName, style: MacosTheme.of(context).typography.caption1),
                                  if (r.downloaded)
                                    Text(
                                      r.localPath!,
                                      style: MacosTheme.of(context).typography.caption1,
                                    ),
                                ],
                              ),
                            ),
                            if (r.downloaded)
                              PushButton(
                                controlSize: ControlSize.small,
                                secondary: state.selectedFrpcPath != r.localPath,
                                onPressed: () {
                                  state.useFrpc(r.localPath!);
                                },
                                child: Text(
                                  state.selectedFrpcPath == r.localPath ? '使用中' : '使用',
                                ),
                              )
                            else
                              PushButton(
                                controlSize: ControlSize.small,
                                onPressed: state.downloadStatus == null
                                    ? () => state.downloadRelease(r)
                                    : null,
                                child: const Text('下载'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
