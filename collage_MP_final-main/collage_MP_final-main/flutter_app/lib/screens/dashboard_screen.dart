import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app.dart';
import '../core/profile_store.dart';
import '../widgets/city_search.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({required this.onAddProfile, super.key});

  final VoidCallback onAddProfile;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? data;
  String? error;
  String? profileName;
  Map<String, dynamic>? selectedCity;
  String? activeProfileId;
  List<Map<String, dynamic>> profiles = [];
  bool changingProfile = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final client = ref.read(apiProvider);
      final stored = await ProfileStore.loadOrImport(
        ref.read(prefsProvider),
        client,
      );
      final profile = stored.activeProfile;
      final city = Map<String, dynamic>.from(profile['city'] as Map);
      final r = await client.post('/assessment', data: {
        'lat': city['lat'],
        'lon': city['lon'],
        'location_name': city['name'],
        'profile': {
          'age': profile['age'],
          'fitness': profile['fitness'],
          'commute_mode': profile['commute_mode'],
          'commute_minutes': profile['commute_minutes'],
          'outdoor_minutes': profile['outdoor_minutes'],
          'sensitivities': profile['sensitivities'],
          'has_purifier': profile['has_purifier'],
        },
      });
      if (!mounted) return;
      setState(() {
        data = r.data;
        profileName = profile['name'] as String;
        selectedCity = city;
        profiles = stored.profiles;
        activeProfileId = profile['id'] as String;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> retry() async {
    setState(() {
      data = null;
      error = null;
    });
    await load();
  }

  Future<void> _selectCity(Map<String, dynamic> city) async {
    final selectedProfileId = activeProfileId;
    if (selectedProfileId == null) {
      throw StateError('No active profile is available.');
    }
    setState(() {
      data = null;
      error = null;
      changingProfile = true;
    });
    try {
      final preferences = ref.read(prefsProvider);
      final client = ref.read(apiProvider);
      final stored = await ProfileStore.loadOrImport(preferences, client);
      final selectedProfile = stored.profiles.firstWhere(
        (profile) => profile['id'] == selectedProfileId,
      );
      final updatedProfiles = stored.profiles
          .map((profile) => profile['id'] == selectedProfileId
              ? ProfileStore.createProfile(
                  name: selectedProfile['name'] as String,
                  source: selectedProfile,
                  city: city,
                )
              : profile)
          .toList();
      await ProfileStore.save(
        preferences,
        updatedProfiles,
        selectedProfileId,
      );
      await load();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => changingProfile = false);
    }
  }

  Future<void> _selectProfile(String id) async {
    if (id == activeProfileId) return;
    setState(() {
      data = null;
      error = null;
      changingProfile = true;
    });
    try {
      await ProfileStore.save(ref.read(prefsProvider), profiles, id);
      await load();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => changingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load the health dashboard.\n$error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (data == null) return const Center(child: CircularProgressIndicator());
    final air = data!['air'], risk = data!['risk'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Health dashboard',
          style: Theme.of(context).textTheme.headlineMedium),
      Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeProfileId,
                isExpanded: true,
                hint: Text(profileName ?? 'Select a profile'),
                items: profiles
                    .map(
                      (profile) => DropdownMenuItem<String>(
                        value: profile['id'] as String,
                        child: Text(profile['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: changingProfile
                    ? null
                    : (id) {
                        if (id != null) _selectProfile(id);
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: changingProfile ? null : widget.onAddProfile,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add profile'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      CitySearch(
        key: ValueKey(activeProfileId),
        label: 'City',
        selectedCity: selectedCity,
        onSelect: _selectCity,
      ),
      const SizedBox(height: 12),
      Card(
          child: ListTile(
              title: const Text('AQI'),
              subtitle: Text(air['category']),
              trailing: Text('${air['aqi']}',
                  style: Theme.of(context).textTheme.headlineMedium))),
      Card(
          child: ListTile(
              title: const Text('Personal risk'),
              subtitle: Text(risk['level']),
              trailing: Text('${risk['score']}'))),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text((data!['interventions']['advice'] as List)
                  .map((x) => x['text'])
                  .join('\n\n')))),
      const Text('India emergency: 112 national emergency · 108 ambulance')
    ]);
  }
}
