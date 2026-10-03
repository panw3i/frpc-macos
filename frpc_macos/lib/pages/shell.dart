import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'about_page.dart';
import 'home_page.dart';
import 'logs_page.dart';

enum _Nav { service, logs, about }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Nav nav = _Nav.service;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final servers = state.servers;
    final selectedId = state.selectedServer?.id;
    final serviceIndex = servers.indexWhere((s) => s.id == selectedId);
    final currentIndex = switch (nav) {
      _Nav.logs => servers.length,
      _Nav.about => servers.length + 1,
      _Nav.service => serviceIndex < 0 ? 0 : serviceIndex,
    };
    final caption = MacosTheme.of(context).typography.caption1.copyWith(
      color: MacosColors.secondaryLabelColor.resolveFrom(context),
      fontSize: 11,
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Frpc Desktop',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: '关于 Frpc Desktop',
                  onSelected: () => setState(() => nav = _Nav.about),
                ),
              ],
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit,
            ),
          ],
        ),
        PlatformMenu(
          label: '服务',
          menus: [
            PlatformMenuItem(
              label: '新增渠道',
              onSelected: () async {
                await context.read<AppState>().addServer();
                setState(() => nav = _Nav.service);
              },
            ),
            PlatformMenuItem(
              label: '全部连接',
              onSelected: () => context.read<AppState>().connect(),
            ),
            PlatformMenuItem(
              label: '全部断开',
              onSelected: () => context.read<AppState>().disconnect(),
            ),
          ],
        ),
      ],
      child: MacosWindow(
        sidebar: Sidebar(
          minWidth: 180,
          startWidth: 200,
          maxWidth: 260,
          bottom: _SidebarFooter(
            onAdd: () async {
              await state.addServer();
              setState(() => nav = _Nav.service);
            },
          ),
          builder: (context, scrollController) {
            return SidebarItems(
              currentIndex: currentIndex,
              scrollController: scrollController,
              itemSize: SidebarItemSize.medium,
              onChanged: (i) {
                if (i < servers.length) {
                  state.selectServer(servers[i].id);
                  setState(() => nav = _Nav.service);
                } else if (i == servers.length) {
                  setState(() => nav = _Nav.logs);
                } else {
                  setState(() => nav = _Nav.about);
                }
              },
              items: [
                for (final s in servers)
                  SidebarItem(
                    leading: MacosIcon(
                      CupertinoIcons.globe,
                      color: state.sessions[s.id]?.running == true
                          ? MacosColors.systemGreenColor
                          : null,
                    ),
                    label: Text(s.label),
                    trailing: state.sessions[s.id]?.running == true
                        ? Text('已连接', style: caption)
                        : null,
                  ),
                const SidebarItem(
                  leading: MacosIcon(CupertinoIcons.doc_plaintext),
                  label: Text('日志'),
                ),
                const SidebarItem(
                  leading: MacosIcon(CupertinoIcons.info_circle),
                  label: Text('关于'),
                ),
              ],
            );
          },
        ),
        child: switch (nav) {
          _Nav.service => const HomePage(),
          _Nav.logs => const LogsPage(),
          _Nav.about => const AboutPage(),
        },
      ),
    );
  }
}

class _SidebarFooter extends StatefulWidget {
  const _SidebarFooter({required this.onAdd});

  final VoidCallback onAdd;

  @override
  State<_SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<_SidebarFooter> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final color = MacosColors.secondaryLabelColor.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onAdd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hover
                  ? MacosColors.controlBackgroundColor
                        .resolveFrom(context)
                        .withValues(alpha: 0.55)
                  : MacosColors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                MacosIcon(CupertinoIcons.plus, size: 13, color: color),
                const SizedBox(width: 8),
                Text(
                  '新增渠道',
                  style: theme.typography.body.copyWith(
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
