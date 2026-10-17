import 'package:flutter/material.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/design_system/hayko_colors.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';
import 'package:calcetto_mvp/features/account/auth_pages.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage(
      {super.key,
      required this.initial,
      this.requiredSetup = false,
      this.onSaved,
      this.email,
      this.saveProfile,
      this.logout});
  final HaykoProfile initial;
  final bool requiredSetup;
  final VoidCallback? onSaved;
  final String? email;
  final Future<HaykoProfile> Function(String, String, String)? saveProfile;
  final Future<void> Function()? logout;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController first, last, nickname, email;
  late HaykoProfile profile;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    profile = widget.initial;
    first = TextEditingController(text: profile.firstName);
    last = TextEditingController(text: profile.lastName);
    nickname = TextEditingController(text: profile.nickname);
    email = TextEditingController(
        text: widget.email ?? Cloud.client.auth.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    for (final c in [first, last, nickname, email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await (widget.saveProfile ?? ProfileService.save)(
          first.text, last.text, nickname.text);
      if (!mounted) return;
      setState(() => profile = saved);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profilo salvato')));
      widget.onSaved?.call();
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'Profilo non salvato. Controlla la connessione e riprova.');
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> logout() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await (widget.logout ?? signOutAccount)();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) setState(() => error = 'Uscita non riuscita. Riprova.');
    }
    if (mounted) setState(() => busy = false);
  }

  String get initials {
    final parts =
        [profile.firstName, profile.lastName].where((s) => s.isNotEmpty);
    return parts.map((s) => s.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) =>
      AccountScaffold(title: 'Profilo', back: !widget.requiredSetup, children: [
        Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: HaykoColors.fieldSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaykoColors.chalk)),
          child: Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xffff7a3d),
                child: Text(initials,
                    style: const TextStyle(
                        color: HaykoColors.fieldBackground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${profile.fullName.isEmpty ? 'Il tuo profilo' : profile.fullName} · Tu',
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  const Text('Il tuo profilo',
                      style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          color: HaykoColors.mutedText,
                          fontWeight: FontWeight.w600)),
                ])),
          ]),
        ),
        if (widget.requiredSetup)
          const Text('Completa i tuoi dati per iniziare a usare HAYKO.'),
        Form(
            key: form,
            child: Column(children: [
              AccountField('Nome', controller: first, validator: requiredName),
              const SizedBox(height: 12),
              AccountField('Cognome',
                  controller: last, validator: requiredName),
              const SizedBox(height: 12),
              AccountField('Nickname',
                  controller: nickname, validator: requiredName),
              const SizedBox(height: 12),
              AccountField('Email privata',
                  controller: email,
                  readOnly: true,
                  keyboard: TextInputType.emailAddress),
            ])),
        const Text('La tua email non è visibile agli altri giocatori.',
            style: TextStyle(
                fontSize: 14, height: 20 / 14, color: HaykoColors.mutedText)),
        if (error != null) Semantics(liveRegion: true, child: Text(error!)),
        if (busy) const LinearProgressIndicator(),
        AccountButton('Salva profilo', onPressed: busy ? null : save),
        AccountButton('Esci dall’account',
            outline: true, onPressed: busy ? null : logout),
      ]);
}
