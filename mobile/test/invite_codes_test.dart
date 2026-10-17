import 'package:flutter_test/flutter_test.dart';
import 'package:calcetto_mvp/features/account/invite_codes.dart';

void main() {
  test('codice breve: maiuscole, minuscole, trattino e spazi', () {
    for (final input in ['HK7P-9M4R', 'hk7p9m4r', ' HK7P - 9M4R\n']) {
      expect(normalizeInviteCode(input), 'hk7p9m4r');
    }
  });
  test('token degli inviti esistenti ancora accettati', () {
    const token =
        'd6c7482eba7243e7ac78c2b0d8e5bfb8f3b903bc38f14381af4d839b146f074f';
    expect(normalizeInviteCode(token.toUpperCase()), token);
  });
  test('codici incompleti, caratteri ambigui e link nel campo codice rifiutati',
      () {
    for (final input in [
      '',
      'HK7P',
      'HK7P9M4R2',
      'HK7P-9M4O',
      'HK7P-9M4I',
      'HK7P-9M40',
      'HK7P-9M41',
      'hayko://join?invite=HK7P9M4R'
    ]) {
      expect(normalizeInviteCode(input), isNull);
    }
  });
  test('errori server tradotti senza confonderli con un id lega', () {
    expect(
        inviteResultError('HAYKO_INVITE_RATE_LIMITED'), contains('15 minuti'));
    expect(inviteResultError('HAYKO_INVITE_EXPIRED'), contains('scaduto'));
    expect(inviteResultError('HAYKO_INVITE_INVALID'), contains('non valido'));
    expect(inviteResultError('qa'), isNull);
  });
}
