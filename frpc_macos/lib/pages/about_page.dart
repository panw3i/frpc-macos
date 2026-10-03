import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final secondary = MacosColors.secondaryLabelColor.resolveFrom(context);
    return MacosScaffold(
      toolBar: const ToolBar(title: Text('关于'), titleWidth: 80, enableBlur: true),
      children: [
        ContentArea(
          builder: (context, sc) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 72,
                      height: 72,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Frpc Desktop', style: theme.typography.title1),
                  const SizedBox(height: 8),
                  Text(
                    '微信公众号 字节笔记本',
                    style: theme.typography.body.copyWith(color: secondary),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
