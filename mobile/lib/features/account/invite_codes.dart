/// Codici manuali senza caratteri ambigui; i token dei link restano validi.
String? normalizeInviteCode(String input) {
  if (input.length > 256) return null;
  final value = input.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
  if (RegExp(r'^[a-hj-np-z2-9]{8}$').hasMatch(value) ||
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    return value;
  }
  return null;
}

String? inviteResultError(Object? result) => switch (result) {
      'HAYKO_INVITE_RATE_LIMITED' =>
        'Troppi tentativi. Attendi 15 minuti prima di riprovare.',
      'HAYKO_INVITE_EXPIRED' =>
        'Invito scaduto o non più disponibile. Chiedi un nuovo invito.',
      'HAYKO_INVITE_INVALID' =>
        'Codice invito non valido. Controllalo e riprova.',
      _ => null,
    };
