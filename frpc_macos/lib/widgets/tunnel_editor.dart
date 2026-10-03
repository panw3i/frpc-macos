import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import 'confirm.dart';
import 'group.dart';

const _proxyTypes = ['tcp', 'udp', 'http', 'https'];

class TunnelEditor extends StatelessWidget {
  const TunnelEditor({super.key, this.serverId, this.fill = false});

  final String? serverId;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = <({String serverId, ProxyItem proxy})>[];
    for (final s in state.servers) {
      if (serverId != null && s.id != serverId) continue;
      for (final p in s.proxies) {
        items.add((serverId: s.id, proxy: p));
      }
    }
    final add = _AddTunnel(serverId: serverId);
    if (!fill) {
      return SettingsGroup(
        title: '隧道',
        dividerIndent: 16,
        children: [
          for (final item in items)
            _TunnelRow(serverId: item.serverId, proxy: item.proxy),
          add,
        ],
      );
    }
    final theme = MacosTheme.of(context);
    return DecoratedBox(
      decoration: settingsCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '隧道',
              style: theme.typography.caption1.copyWith(
                color: MacosColors.secondaryLabelColor.resolveFrom(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: add,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final item in items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: _TunnelRow(
                      serverId: item.serverId,
                      proxy: item.proxy,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Container(
                      height: 0.5,
                      color: MacosColors.separatorColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTunnel extends StatelessWidget {
  const _AddTunnel({this.serverId});
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = MacosTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => state.addProxy(serverId: serverId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.plus_circle_fill,
              size: 16,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              '增加隧道',
              style: theme.typography.body.copyWith(color: theme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _TunnelRow extends StatelessWidget {
  const _TunnelRow({required this.serverId, required this.proxy});

  final String serverId;
  final ProxyItem proxy;

  bool get _http => proxy.type == 'http' || proxy.type == 'https';

  String get _domain {
    if (proxy.customDomains.isNotEmpty) return proxy.customDomains.first;
    return proxy.subdomain;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Row(
      children: [
        MacosSwitch(
          size: ControlSize.mini,
          value: proxy.enabled,
          onChanged: (v) => state.updateProxyById(
            proxy.id,
            (p) => p.enabled = v,
            serverId: serverId,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: PersistentTextField(
            value: proxy.name,
            borderless: true,
            placeholder: '名称',
            onChanged: (v) => state.updateProxyById(
              proxy.id,
              (p) => p.name = v,
              serverId: serverId,
            ),
          ),
        ),
        SizedBox(
          width: 86,
          child: MacosPopupButton<String>(
            value: _proxyTypes.contains(proxy.type) ? proxy.type : 'tcp',
            onChanged: (v) {
              if (v == null) return;
              state.updateProxyById(
                proxy.id,
                (p) => p.type = v,
                serverId: serverId,
              );
            },
            items: [
              for (final t in _proxyTypes)
                MacosPopupMenuItem(value: t, child: Text(t.toUpperCase())),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: PersistentTextField(
            value: '${proxy.localPort}',
            borderless: true,
            placeholder: '本机',
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                state.updateProxyById(
                  proxy.id,
                  (p) => p.localPort = n,
                  serverId: serverId,
                );
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '→',
            style: MacosTheme.of(context).typography.caption1.copyWith(
              color: MacosColors.tertiaryLabelColor.resolveFrom(context),
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: PersistentTextField(
            value: _http ? _domain : '${proxy.remotePort}',
            borderless: true,
            placeholder: _http ? '域名' : '远端',
            onChanged: (v) {
              if (_http) {
                state.updateProxyById(
                  proxy.id,
                  (p) {
                    final t = v.trim();
                    if (t.contains('.')) {
                      p.customDomains = t.isEmpty ? [] : [t];
                      p.subdomain = '';
                    } else {
                      p.customDomains = [];
                      p.subdomain = t;
                    }
                  },
                  serverId: serverId,
                );
              } else {
                final n = int.tryParse(v);
                if (n != null) {
                  state.updateProxyById(
                    proxy.id,
                    (p) => p.remotePort = n,
                    serverId: serverId,
                  );
                }
              }
            },
          ),
        ),
        MacosIconButton(
          boxConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          icon: MacosIcon(
            CupertinoIcons.minus,
            size: 13,
            color: MacosColors.secondaryLabelColor.resolveFrom(context),
          ),
          onPressed: () async {
            final label = proxy.name.trim().isEmpty ? '这条隧道' : proxy.name;
            final ok = await confirmDelete(
              context,
              title: '删除隧道？',
              message: '删除「$label」。',
            );
            if (ok) {
              await state.removeProxy(proxy.id, serverId: serverId);
            }
          },
        ),
      ],
    );
  }
}
