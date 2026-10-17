import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:calcetto_mvp/core/services/cloud.dart';

class HaykoProfile {
  const HaykoProfile(this.firstName, this.lastName, this.nickname);
  final String firstName, lastName, nickname;
  bool get complete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      nickname.trim().isNotEmpty;
  String get fullName => '$firstName $lastName'.trim();
  Map<String, dynamic> toJson() =>
      {'first_name': firstName, 'last_name': lastName, 'nickname': nickname};
  factory HaykoProfile.fromJson(Map<String, dynamic> json) => HaykoProfile(
      json['first_name'] as String? ?? '',
      json['last_name'] as String? ?? '',
      json['nickname'] as String? ?? '');
}

class ProfileService {
  static String key(String id) => 'hayko.profile.$id';
  static Future<HaykoProfile> load() async {
    final userId = Cloud.client.auth.currentUser!.id;
    final prefs = await SharedPreferences.getInstance();
    try {
      final data =
          Map<String, dynamic>.from(await Cloud.client.rpc('hayko_profile'));
      await prefs.setString(key(userId), jsonEncode(data));
      return HaykoProfile.fromJson(data);
    } catch (_) {
      final cached = prefs.getString(key(userId));
      if (cached == null) rethrow;
      return HaykoProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached)));
    }
  }

  static Future<HaykoProfile> save(
      String first, String last, String nickname) async {
    final userId = Cloud.client.auth.currentUser!.id;
    final data = Map<String, dynamic>.from(
        await Cloud.client.rpc('hayko_save_profile', params: {
      'p_first': first.trim(),
      'p_last': last.trim(),
      'p_nickname': nickname.trim(),
    }));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key(userId), jsonEncode(data));
    return HaykoProfile.fromJson(data);
  }
}
