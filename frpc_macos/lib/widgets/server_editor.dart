import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import 'group.dart';

class ServerForm extends StatelessWidget {
  const ServerForm({super.key, required this.server});

  final FrpsServer server;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SettingsGroup(
      children: [
        LabeledField(
          label: '名称',
          child: PersistentTextField(
            value: server.name,
            borderless: true,
            placeholder: '例如 oracle',
            onChanged: (v) =>
                state.updateServerById(server.id, (s) => s.name = v),
          ),
        ),
        LabeledField(
          label: '地址',
          child: PersistentTextField(
            value: server.addr,
            borderless: true,
            placeholder: 'IP 或域名',
            onChanged: (v) =>
                state.updateServerById(server.id, (s) => s.addr = v),
          ),
        ),
        LabeledField(
          label: '端口',
          child: PersistentTextField(
            value: '${server.port}',
            borderless: true,
            placeholder: '7000',
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                state.updateServerById(server.id, (s) => s.port = n);
              }
            },
          ),
        ),
        LabeledField(
          label: 'Token',
          child: PersistentTextField(
            value: server.token,
            borderless: true,
            placeholder: '认证令牌',
            obscureText: true,
            onChanged: (v) =>
                state.updateServerById(server.id, (s) => s.token = v),
          ),
        ),
      ],
    );
  }
}
