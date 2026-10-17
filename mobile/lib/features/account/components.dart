import 'package:flutter/material.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/design_system/hayko_home.dart';

class AccountScaffold extends StatelessWidget {
  const AccountScaffold(
      {super.key,
      required this.title,
      required this.children,
      this.back = true});
  final String title;
  final List<Widget> children;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          centerTitle: false,
          automaticallyImplyLeading: false,
          leadingWidth: back ? 72 : null,
          leading: back
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Align(
                      alignment: Alignment.topLeft,
                      child: HaykoIconAction(
                          tooltip: 'Indietro',
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.maybePop(context))),
                )
              : null,
          titleSpacing: back ? 0 : 24,
          title: SizedBox(
              height: 72,
              child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w700)))),
        ),
        body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (final child in children)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12), child: child)
              ],
            )),
      );
}

class AccountButton extends StatelessWidget {
  const AccountButton(this.label,
      {super.key, required this.onPressed, this.outline = false});
  final String label;
  final VoidCallback? onPressed;
  final bool outline;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'BricolageGrotesque',
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0)),
    );
    return outline
        ? OutlinedButton(
            style: style.copyWith(
                backgroundColor:
                    const WidgetStatePropertyAll(HaykoColors.fieldSurface),
                side: const WidgetStatePropertyAll(
                    BorderSide(color: HaykoColors.fieldLine))),
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center),
          )
        : FilledButton(
            style: style,
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center));
  }
}

class AccountField extends StatefulWidget {
  const AccountField(this.label,
      {super.key,
      required this.controller,
      this.password = false,
      this.readOnly = false,
      this.keyboard,
      this.validator,
      this.autofillHints});
  final String label;
  final TextEditingController controller;
  final bool password, readOnly;
  final TextInputType? keyboard;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  @override
  State<AccountField> createState() => _AccountFieldState();
}

class _AccountFieldState extends State<AccountField> {
  bool hidden = true;
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => focus.requestFocus(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: HaykoColors.fieldSurface,
              border: Border.all(color: HaykoColors.fieldLine),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                    child: Text(widget.label,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w600,
                            color: HaykoColors.mutedText))),
                const SizedBox(height: 8),
                Semantics(
                    label: widget.label,
                    child: TextFormField(
                      focusNode: focus,
                      controller: widget.controller,
                      readOnly: widget.readOnly,
                      obscureText: widget.password && hidden,
                      enableSuggestions: !widget.password,
                      autocorrect: !widget.password,
                      keyboardType: widget.keyboard,
                      autofillHints: widget.autofillHints,
                      validator: widget.validator,
                      style: const TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        suffixIcon: widget.password
                            ? IconButton(
                                tooltip: hidden
                                    ? 'Mostra password'
                                    : 'Nascondi password',
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              )
                            : null,
                      ),
                    )),
              ]),
        ),
      );
}

String? requiredName(String? value) => value == null || value.trim().isEmpty
    ? 'Compila questo campo'
    : value.trim().length > 60
        ? 'Massimo 60 caratteri'
        : null;
String? validEmail(String? value) => value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Inserisci un’email valida'
    : null;
String? validPassword(String? value) =>
    value == null || value.length < 8 ? 'Usa almeno 8 caratteri' : null;
