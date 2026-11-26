import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profilesKey = 'aqi.profiles.v1';
const _activeProfileKey = 'aqi.activeProfileId';

class LocalProfiles {
  const LocalProfiles({required this.profiles, required this.activeProfile});

  final List<Map<String, dynamic>> profiles;
  final Map<String, dynamic> activeProfile;
}

class ProfileStore {
  static const defaultCity = <String, dynamic>{
    'name': 'New Delhi',
    'lat': 28.6139,
    'lon': 77.209,
    'country': 'IN',
  };

  static Map<String, dynamic> createProfile({
    String name = 'My profile',
    Map<String, dynamic>? source,
    Map<String, dynamic>? city,
  }) {
    final values = source ?? const <String, dynamic>{};
    return {
      'id': values['id']?.toString() ??
          'profile-${DateTime.now().microsecondsSinceEpoch}',
      'name': name,
      'age': _integer(values['age'], 30),
      'fitness': values['fitness'] ?? 'moderate',
      'commute_mode': values['commute_mode'] ?? 'walk',
      'commute_minutes': _integer(values['commute_minutes'], 30),
      'outdoor_minutes': _integer(values['outdoor_minutes'], 60),
      'sensitivities': (values['sensitivities'] as List?)
              ?.map((value) => value.toString())
              .toList() ??
          <String>[],
      'has_purifier': values['has_purifier'] == true,
      'city': _normalizeCity(city ?? values['city'] as Map<String, dynamic>?),
    };
  }

  static Future<LocalProfiles> loadOrImport(
    SharedPreferences preferences,
    Dio client,
  ) async {
    final stored = preferences.getString(_profilesKey);
    late final List<Map<String, dynamic>> profiles;
    if (stored != null) {
      final decoded = jsonDecode(stored);
      if (decoded is! List || decoded.isEmpty) {
        throw const FormatException('Saved profiles are invalid.');
      }
      profiles = decoded
          .map((item) => createProfile(
                name: (item as Map)['name']?.toString() ?? 'My profile',
                source: Map<String, dynamic>.from(item),
                city: item['city'] is Map
                    ? Map<String, dynamic>.from(item['city'] as Map)
                    : null,
              ))
          .toList();
    } else {
      final response = await client.get('/profiles');
      final legacyProfiles = response.data;
      if (legacyProfiles is! List) {
        throw const FormatException(
            'The backend returned an invalid profile list.');
      }
      final source = legacyProfiles.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(legacyProfiles.first as Map);
      profiles = [
        createProfile(
          name: 'My profile',
          source: source,
          city: defaultCity,
        )
      ];
    }

    final requestedId = preferences.getString(_activeProfileKey);
    final activeProfile = profiles.firstWhere(
      (profile) => profile['id'] == requestedId,
      orElse: () => profiles.first,
    );
    final saved = await preferences.setString(
      _profilesKey,
      jsonEncode(profiles),
    );
    if (!saved) {
      throw StateError('Could not save profiles on this device.');
    }
    final activeSaved = await preferences.setString(
      _activeProfileKey,
      activeProfile['id'] as String,
    );
    if (!activeSaved) {
      throw StateError('Could not save the selected profile on this device.');
    }
    return LocalProfiles(profiles: profiles, activeProfile: activeProfile);
  }

  static Future<void> save(
    SharedPreferences preferences,
    List<Map<String, dynamic>> profiles,
    String activeProfileId,
  ) async {
    final saved = await preferences.setString(
      _profilesKey,
      jsonEncode(profiles),
    );
    if (!saved) {
      throw StateError('Could not save profiles on this device.');
    }
    final activeSaved =
        await preferences.setString(_activeProfileKey, activeProfileId);
    if (!activeSaved) {
      throw StateError('Could not save the selected profile on this device.');
    }
  }

  static int _integer(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, dynamic> _normalizeCity(
    Map<String, dynamic>? city,
  ) {
    final value = city ?? defaultCity;
    final lat = value['lat'];
    final lon = value['lon'];
    final latitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final longitude = lon is num ? lon.toDouble() : double.tryParse('$lon');
    if (latitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude == null ||
        longitude < -180 ||
        longitude > 180) {
      return Map<String, dynamic>.from(defaultCity);
    }
    return {
      ...value,
      'name': value['name']?.toString() ?? 'Selected city',
      'lat': latitude,
      'lon': longitude,
    };
  }
}
