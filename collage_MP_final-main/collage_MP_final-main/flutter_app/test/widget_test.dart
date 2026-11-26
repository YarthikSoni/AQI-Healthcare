import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aqi_public_health_monitor/core/profile_store.dart';

void main() {
  testWidgets('Flutter test environment builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('AQI Monitor'))),
    );
    expect(find.text('AQI Monitor'), findsOneWidget);
  });

  test('local profiles retain their IDs and selected city', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profiles = [
      ProfileStore.createProfile(
        name: 'Home',
        city: {'name': 'Mumbai', 'lat': 19.076, 'lon': 72.8777},
      ),
      ProfileStore.createProfile(
        name: 'Work',
        city: {'name': 'Pune', 'lat': 18.5204, 'lon': 73.8567},
      ),
    ];
    final selectedId = profiles.last['id'] as String;

    await ProfileStore.save(preferences, profiles, selectedId);
    final loaded = await ProfileStore.loadOrImport(preferences, Dio());

    expect(loaded.activeProfile['id'], selectedId);
    expect(loaded.activeProfile['city']['name'], 'Pune');
    expect(loaded.profiles.map((profile) => profile['id']), [
      profiles.first['id'],
      profiles.last['id'],
    ]);
  });
}
