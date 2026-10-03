import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showMacosAlertDialog<bool>(
    context: context,
    builder: (context) => MacosAlertDialog(
      appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle, size: 48),
      title: Text(title),
      message: Text(message, textAlign: TextAlign.center),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('删除'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
    ),
  );
  return ok == true;
}
