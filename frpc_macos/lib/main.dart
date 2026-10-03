import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import 'agent_server.dart';
import 'app_state.dart';
import 'pages/shell.dart';

Future<void> main() async {
  if (!kIsWeb && Platform.isMacOS) {
    const config = MacosWindowUtilsConfig();
    await config.apply();
    await WindowManipulator.setWindowMinSize(const Size(960, 640));
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  final state = AppState();
  await state.load();
  await AgentServer(state).start();
  runApp(FrpcApp(state: state));
}

class FrpcApp extends StatelessWidget {
  const FrpcApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MacosApp(
        title: 'Frpc Desktop',
        debugShowCheckedModeBanner: false,
        theme: MacosThemeData.light(),
        darkTheme: MacosThemeData.dark(),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}
