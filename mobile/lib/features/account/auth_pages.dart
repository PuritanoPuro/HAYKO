import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calcetto_mvp/core/services/cloud.dart';
import 'package:calcetto_mvp/core/services/rotation_alerts.dart';
import 'package:calcetto_mvp/features/account/components.dart';
import 'package:calcetto_mvp/features/account/profile_page.dart';
import 'package:calcetto_mvp/features/account/profile_service.dart';

final passwordRecovery = ValueNotifier<bool>(false);

String accountError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login')) {
      return 'Email o password non corretti.';
    }
    if (message.contains('not confirmed')) {
      return 'Conferma prima la tua email con il codice ricevuto.';
    }
    if (message.contains('rate') || message.contains('seconds')) {
      return 'Troppi tentativi. Attendi prima di riprovare.';
    }
    if (message.contains('expired') || message.contains('token')) {
      return 'Codice non valido o scaduto. Richiedine uno nuovo.';
    }
    if (message.contains('authorized') || message.contains('sending')) {
      return 'Invio email non disponibile. Riprova più tardi.';
    }
    return 'Operazione non riuscita. Controlla i dati e riprova.';
  }
  return 'Connessione non disponibile. Riprova quando sei online.';
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key, required this.signedIn});
  final Widget Function(String userId) signedIn;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  StreamSubscription<AuthState>? subscription;
  String? userId;
  Future<HaykoProfile>? profile;
  @override
  void initState() {
    super.initState();
    listen();
    passwordRecovery.addListener(recoveryChanged);
  }

  void recoveryChanged() {
    if (mounted) setState(() {});
  }

  void listen() {
    if (!Cloud.ready) return;
    userId = Cloud.client.auth.currentUser?.id;
    if (userId != null) profile = ProfileService.load();
    subscription = Cloud.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      final next = state.session?.user.id;
      final changed = next != userId;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        passwordRecovery.value = true;
      }
      if (changed) {
        userId = next;
        profile = next == null ? null : ProfileService.load();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
      setState(() {});
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    subscription?.cancel();
    passwordRecovery.removeListener(recoveryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Cloud.ready) {
      return AccountScaffold(title: 'HAYKO', back: false, children: [
        const Text('Impossibile avviare la connessione. Riprova.'),
        AccountButton('Riprova', onPressed: () async {
          await Cloud.initialize();
          if (!mounted) return;
          listen();
          setState(() {});
        }),
      ]);
    }
    if (userId == null) return const AuthPage();
    if (passwordRecovery.value) {
      return NewPasswordPage(onDone: () => passwordRecovery.value = false);
    }
    return FutureBuilder<HaykoProfile>(
        future: profile,
        builder: (context, result) {
          if (result.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (result.hasError) {
            return AccountScaffold(title: 'HAYKO', back: false, children: [
              const Text(
                  'Impossibile caricare il profilo. Controlla la connessione e riprova.'),
              AccountButton('Riprova',
                  onPressed: () =>
                      setState(() => profile = ProfileService.load())),
              AccountButton('Esci dall’account', outline: true,
                  onPressed: () async {
                await signOutAccount();
              }),
            ]);
          }
          if (!result.data!.complete) {
            return ProfilePage(
                initial: result.data!,
                requiredSetup: true,
                onSaved: () => setState(() => profile = ProfileService.load()));
          }
          return widget.signedIn(userId!);
        });
  }
}

Future<void> signOutAccount() async {
  await Cloud.client.auth.signOut(scope: SignOutScope.local);
  passwordRecovery.value = false;
  RotationAlerts.instance.sources.clear();
  await RotationAlerts.instance.sync([]);
}

enum _AuthStep { login, signup, recovery, verifySignup, verifyRecovery }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  var form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      nickname = TextEditingController();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      code = TextEditingController();
  _AuthStep step = _AuthStep.login;
  bool busy = false;
  String? error;
  String get address => email.text.trim();
  bool get verification =>
      step == _AuthStep.verifySignup || step == _AuthStep.verifyRecovery;
  @override
  void dispose() {
    for (final c in [first, last, nickname, email, password, confirm, code]) {
      c.dispose();
    }
    super.dispose();
  }

  void change(_AuthStep next) {
    setState(() {
      step = next;
      form = GlobalKey<FormState>();
      error = null;
      password.clear();
      confirm.clear();
      code.clear();
    });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    await run(() async {
      switch (step) {
        case _AuthStep.login:
          try {
            await Cloud.client.auth
                .signInWithPassword(email: address, password: password.text);
          } on AuthException catch (e) {
            if (e.message.toLowerCase().contains('not confirmed')) {
              if (mounted) change(_AuthStep.verifySignup);
            } else {
              rethrow;
            }
          }
          break;
        case _AuthStep.signup:
          final response = await Cloud.client.auth
              .signUp(email: address, password: password.text, data: {
            'first_name': first.text.trim(),
            'last_name': last.text.trim(),
            'nickname': nickname.text.trim()
          });
          if (mounted && response.session == null) {
            change(_AuthStep.verifySignup);
          }
          break;
        case _AuthStep.recovery:
          await Cloud.client.auth.resetPasswordForEmail(address);
          if (mounted) change(_AuthStep.verifyRecovery);
          break;
        case _AuthStep.verifySignup:
          await Cloud.client.auth.verifyOTP(
              email: address, token: code.text.trim(), type: OtpType.email);
          break;
        case _AuthStep.verifyRecovery:
          passwordRecovery.value = true;
          try {
            await Cloud.client.auth.verifyOTP(
                email: address,
                token: code.text.trim(),
                type: OtpType.recovery);
          } catch (_) {
            passwordRecovery.value = false;
            rethrow;
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final signup = step == _AuthStep.signup;
    final login = step == _AuthStep.login;
    final heading = signup
        ? 'Crea il tuo account'
        : login
            ? 'Accedi a HAYKO'
            : verification
                ? 'Controlla la tua email'
                : 'Recupera la password';
    return AccountScaffold(
        title: 'HAYKO',
        back: false,
        toolbarHeight: 64,
        children: [
          Text(heading,
              style: const TextStyle(
                  fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w800)),
          if (verification)
            Text(
                'Inserisci il codice inviato a $address. Se l’account esiste ed è abilitato riceverai l’email.'),
          IgnorePointer(
              ignoring: busy,
              child: Form(
                  key: form,
                  child: AutofillGroup(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        if (signup) ...[
                          AccountField('Nome',
                              controller: first,
                              validator: requiredName,
                              autofillHints: const [AutofillHints.givenName]),
                          const SizedBox(height: 12),
                          AccountField('Cognome',
                              controller: last,
                              validator: requiredName,
                              autofillHints: const [AutofillHints.familyName]),
                          const SizedBox(height: 12),
                          AccountField('Nickname',
                              controller: nickname,
                              validator: requiredName,
                              autofillHints: const [AutofillHints.nickname]),
                          const SizedBox(height: 12),
                        ],
                        if (!verification)
                          AccountField('Email',
                              controller: email,
                              validator: validEmail,
                              keyboard: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email]),
                        if (login || signup) ...[
                          const SizedBox(height: 12),
                          AccountField('Password',
                              controller: password,
                              password: true,
                              validator: signup
                                  ? validPassword
                                  : (v) => v == null || v.isEmpty
                                      ? 'Inserisci la password'
                                      : null,
                              autofillHints: [
                                signup
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password
                              ]),
                        ],
                        if (signup) ...[
                          const SizedBox(height: 12),
                          AccountField('Ripeti password',
                              controller: confirm,
                              password: true,
                              validator: (v) => v != password.text
                                  ? 'Le password non coincidono'
                                  : validPassword(v)),
                        ],
                        if (verification)
                          AccountField('Codice email',
                              controller: code,
                              keyboard: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              validator: (v) => v == null ||
                                      !RegExp(r'^[0-9]{6,10}$')
                                          .hasMatch(v.trim())
                                  ? 'Inserisci il codice ricevuto'
                                  : null),
                      ])))),
          if (error != null)
            Semantics(
                liveRegion: true,
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (busy) const LinearProgressIndicator(),
          AccountButton(
              signup
                  ? 'Crea account'
                  : login
                      ? 'Accedi'
                      : verification
                          ? 'Conferma codice'
                          : 'Invia codice di recupero',
              onPressed: busy ? null : submit),
          if (login) ...[
            AccountButton('Crea un account',
                outline: true,
                onPressed: busy ? null : () => change(_AuthStep.signup)),
            TextButton(
                onPressed: busy ? null : () => change(_AuthStep.recovery),
                child: const Text('Password dimenticata?')),
          ] else
            AccountButton('Torna all’accesso',
                outline: true,
                onPressed: busy ? null : () => change(_AuthStep.login)),
          if (verification)
            TextButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          if (step == _AuthStep.verifyRecovery) {
                            await Cloud.client.auth
                                .resetPasswordForEmail(address);
                          } else {
                            await Cloud.client.auth
                                .resend(type: OtpType.signup, email: address);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Richiesta di invio completata. Controlla la tua email.')));
                          }
                        }),
                child: const Text('Invia un nuovo codice')),
        ]);
  }
}

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(), confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Cloud.client.auth
          .updateUser(UserAttributes(password: password.text));
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => error = accountError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) =>
      AccountScaffold(title: 'Nuova password', back: false, children: [
        Form(
            key: form,
            child: Column(children: [
              AccountField('Nuova password',
                  controller: password,
                  password: true,
                  validator: validPassword,
                  autofillHints: const [AutofillHints.newPassword]),
              const SizedBox(height: 12),
              AccountField('Ripeti password',
                  controller: confirm,
                  password: true,
                  validator: (v) => v != password.text
                      ? 'Le password non coincidono'
                      : validPassword(v)),
            ])),
        if (error != null) Text(error!),
        if (busy) const LinearProgressIndicator(),
        AccountButton('Salva password', onPressed: busy ? null : save),
        AccountButton('Esci dall’account',
            outline: true,
            onPressed: busy
                ? null
                : () async {
                    await signOutAccount();
                  }),
      ]);
}
