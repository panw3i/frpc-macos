import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

BoxDecoration settingsCardDecoration(BuildContext context) {
  final isDark = MacosTheme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF3A3A3C) : MacosColors.white,
    borderRadius: BorderRadius.circular(10),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title = '',
    required this.children,
    this.dividerIndent = 108,
  });

  final String title;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Text(
                title,
                style: theme.typography.caption1.copyWith(
                  color: MacosColors.secondaryLabelColor.resolveFrom(context),
                ),
              ),
            ),
          DecoratedBox(
            decoration: settingsCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.only(left: dividerIndent),
                      child: Container(
                        height: 0.5,
                        color: MacosColors.separatorColor.withValues(alpha: 0.55),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: children[i],
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

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: MacosTheme.of(context).typography.body.copyWith(
              color: MacosColors.labelColor.resolveFrom(context),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class PersistentTextField extends StatefulWidget {
  const PersistentTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.obscureText = false,
    this.borderless = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool obscureText;
  final bool borderless;

  @override
  State<PersistentTextField> createState() => _PersistentTextFieldState();
}

class _PersistentTextFieldState extends State<PersistentTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(PersistentTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.borderless) {
      return MacosTextField.borderless(
        controller: _controller,
        placeholder: widget.placeholder,
        obscureText: widget.obscureText,
        onChanged: widget.onChanged,
      );
    }
    return MacosTextField(
      controller: _controller,
      placeholder: widget.placeholder,
      obscureText: widget.obscureText,
      onChanged: widget.onChanged,
    );
  }
}
