import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? inviteCode(Uri uri) {
  if (!['hayko', 'bordocampo'].contains(uri.scheme) || uri.host != 'join') {
    return null;
  }
  final code = uri.queryParameters['invite'];
  return code != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(code)
      ? code.toLowerCase()
      : null;
}

abstract final class InviteLinks {
  static final pending = ValueNotifier<String?>(null);
  static StreamSubscription<Uri>? subscription;
  static Future<void> clearPending() async {
    pending.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hayko.pending_invite');
  }

  static Future<void> accept(Uri uri) async {
    final code = inviteCode(uri);
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hayko.pending_invite', code);
    pending.value = code;
  }

  static Future<void> initialize() async {
    final links = AppLinks();
    try {
      final prefs = await SharedPreferences.getInstance();
      pending.value = prefs.getString('hayko.pending_invite');
      final initial = await links.getInitialLink();
      if (initial != null) await accept(initial);
      subscription = links.uriLinkStream.listen((uri) {
        unawaited(accept(uri).catchError((Object _) {}));
      }, onError: (Object _) {});
    } catch (_) {/* Gli inviti restano utilizzabili anche tramite codice. */}
  }
}
