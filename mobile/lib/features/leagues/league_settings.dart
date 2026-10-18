import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/domain/domain.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/shared/ui.dart';
import 'package:calcetto_mvp/shared/customization.dart';

class LeagueSettingsPage extends StatefulWidget {
  final League league;
  final Save save;
  final Save? delete;
  const LeagueSettingsPage(
      {super.key, required this.league, required this.save, this.delete});
  @override
  State<LeagueSettingsPage> createState() => _LeagueSettingsPageState();
}

class _LeagueSettingsPageState extends State<LeagueSettingsPage> {
  League get l => widget.league;
  late final TextEditingController name;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: l.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    final next = name.text.trim();
    if (next.isEmpty) {
      showError(context, 'Inserisci il nome della lega.');
      return;
    }
    final previous = l.name;
    setState(() => busy = true);
    l.name = next;
    try {
      await widget.save();
    } catch (e) {
      l.name = previous;
      name.text = previous;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> changeColor({required bool primary}) async {
    final previous = primary ? l.primaryColor : l.secondaryColor;
    final next = await chooseColor(context, previous);
    if (next == null || next == previous || !mounted) return;
    setState(() {
      busy = true;
      if (primary) {
        l.primaryColor = next;
      } else {
        l.secondaryColor = next;
      }
    });
    try {
      await widget.save();
    } catch (e) {
      if (primary) {
        l.primaryColor = previous;
      } else {
        l.secondaryColor = previous;
      }
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> remove() async {
    if (!await confirm(context, 'Eliminare ${l.name}?',
        'Verranno eliminate la lega, le partite, le competizioni e le statistiche contenute.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.delete!();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: leagueTheme(context, l),
      child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            centerTitle: false,
            leadingWidth: 52,
            leading: IconButton(
                tooltip: 'Indietro',
                icon: const Icon(Icons.arrow_back, size: 24),
                onPressed: () => Navigator.maybePop(context)),
            titleSpacing: 0,
            title: const Text('Impostazioni lega',
                style: TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 20,
                    height: 26 / 20,
                    fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
              top: false,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                _LeagueNameField(controller: name),
                const SizedBox(height: 12),
                _PrimaryButton(
                    label: 'Salva nome', onPressed: busy ? null : saveName),
                const SizedBox(height: 12),
                _ColorField(
                    label: 'Colore primario',
                    color: l.primaryColor,
                    onTap: busy ? null : () => changeColor(primary: true)),
                const SizedBox(height: 12),
                _ColorField(
                    label: 'Colore secondario',
                    color: l.secondaryColor,
                    onTap: busy ? null : () => changeColor(primary: false)),
                const SizedBox(height: 12),
                if (widget.delete != null && l.president)
                  _DangerButton(
                      label: 'Elimina lega', onPressed: busy ? null : remove),
              ]))));
}

class _LeagueNameField extends StatelessWidget {
  const _LeagueNameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HaykoColors.fieldSurface,
            border: Border.all(color: HaykoColors.fieldLine),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nome lega',
              style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: HaykoColors.mutedText)),
          const SizedBox(height: 8),
          Expanded(
              child: TextField(
            key: const ValueKey('league-name-field'),
            controller: controller,
            maxLength: 60,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none),
          )),
        ]),
      );
}

class _ColorField extends StatelessWidget {
  const _ColorField(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final int color;
  final VoidCallback? onTap;

  String get hex =>
      '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) => Material(
        color: HaykoColors.fieldSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w600,
                              color: HaykoColors.mutedText)),
                      const SizedBox(height: 4),
                      Text(hex,
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                    ])),
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Color(color), shape: BoxShape.circle)),
              ]),
            ),
          ),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: HaykoColors.chalk,
          foregroundColor: HaykoColors.fieldBackground,
          disabledBackgroundColor: HaykoColors.chalk.withValues(alpha: .45),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 16, height: 1.5, fontWeight: FontWeight.w700)),
      onPressed: onPressed,
      child: Text(label));
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
      style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffffb4ab),
          side: const BorderSide(color: Color(0xffffb4ab)),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 16, height: 1.5, fontWeight: FontWeight.w700)),
      onPressed: onPressed,
      child: Text(label));
}
