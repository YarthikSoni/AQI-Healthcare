import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/app.dart';
import '../core/profile_store.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Map<String, dynamic>> profiles = [];
  Map<String, dynamic>? form;
  String? activeProfileId;
  String newProfileName = '';
  String? error;
  String? status;
  bool loading = true;
  bool saving = false;
  bool _createProfileWhenReady = false;
  final TextEditingController _newProfileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _newProfileController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final result = await ProfileStore.loadOrImport(
        ref.read(prefsProvider),
        ref.read(apiProvider),
      );
      if (!mounted) return;
      setState(() {
        profiles = result.profiles;
        activeProfileId = result.activeProfile['id'] as String;
        form = _copyProfile(result.activeProfile);
        loading = false;
      });
      if (_createProfileWhenReady) {
        _createProfileWhenReady = false;
        await createNewProfile();
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Map<String, dynamic> _copyProfile(Map<String, dynamic> profile) => {
        ...profile,
        'city': Map<String, dynamic>.from(profile['city'] as Map),
        'sensitivities': List<String>.from(profile['sensitivities'] as List),
      };

  List<Map<String, dynamic>> _profilesWithCurrentEdits() {
    final current = form;
    final selectedId = activeProfileId;
    if (current == null || selectedId == null) return profiles;
    if ((current['name'] as String).trim().isEmpty) {
      throw StateError('Enter a name for this profile.');
    }
    return profiles
        .map((profile) => profile['id'] == selectedId
            ? ProfileStore.createProfile(
                name: (current['name'] as String).trim(),
                source: current,
                city: Map<String, dynamic>.from(current['city'] as Map),
              )
            : profile)
        .toList();
  }

  void _setField(String field, dynamic value) {
    setState(() {
      form = {...?form, field: value};
      status = null;
    });
  }

  Future<void> _saveCurrentProfile({bool showStatus = true}) async {
    if (form == null || activeProfileId == null) return;
    final nextProfiles = _profilesWithCurrentEdits();
    await ProfileStore.save(
      ref.read(prefsProvider),
      nextProfiles,
      activeProfileId!,
    );
    if (!mounted) return;
    setState(() {
      profiles = nextProfiles;
      form = _copyProfile(
        nextProfiles.firstWhere((profile) => profile['id'] == activeProfileId),
      );
      status = showStatus ? 'Profile saved on this device.' : status;
    });
  }

  Future<void> _selectProfile(String id) async {
    if (id == activeProfileId) return;
    setState(() {
      saving = true;
      status = null;
      error = null;
    });
    try {
      final nextProfiles = _profilesWithCurrentEdits();
      await ProfileStore.save(ref.read(prefsProvider), nextProfiles, id);
      if (!mounted) return;
      final selected =
          nextProfiles.firstWhere((profile) => profile['id'] == id);
      setState(() {
        profiles = nextProfiles;
        activeProfileId = id;
        form = _copyProfile(selected);
        saving = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        saving = false;
      });
    }
  }

  Future<void> createNewProfile() async {
    if (loading || form == null) {
      _createProfileWhenReady = true;
      return;
    }
    var name = 'New profile';
    var suffix = 2;
    while (profiles.any((profile) => profile['name'] == name)) {
      name = 'New profile $suffix';
      suffix++;
    }
    await _addProfile(nameOverride: name);
  }

  Future<void> _addProfile({String? nameOverride}) async {
    final name = (nameOverride ?? newProfileName).trim();
    if (name.isEmpty) {
      setState(() => status = 'Enter a profile name first.');
      return;
    }
    final nextProfiles = _profilesWithCurrentEdits();
    final selected = nextProfiles.firstWhere(
      (profile) => profile['id'] == activeProfileId,
    );
    final profile = ProfileStore.createProfile(
      name: name,
      city: Map<String, dynamic>.from(selected['city'] as Map),
    );
    final allProfiles = [...nextProfiles, profile];
    setState(() {
      saving = true;
      error = null;
      status = null;
    });
    try {
      await ProfileStore.save(
        ref.read(prefsProvider),
        allProfiles,
        profile['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        profiles = allProfiles;
        activeProfileId = profile['id'] as String;
        form = _copyProfile(profile);
        newProfileName = '';
        _newProfileController.clear();
        saving = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        saving = false;
      });
    }
  }

  Future<void> _deleteProfile() async {
    final current = form;
    if (current == null || profiles.length <= 1) return;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete profile?'),
            content: Text('Delete ${current['name']} from this device?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;

    final remaining =
        profiles.where((profile) => profile['id'] != activeProfileId).toList();
    final nextActive = remaining.first;
    setState(() {
      saving = true;
      error = null;
      status = null;
    });
    try {
      await ProfileStore.save(
        ref.read(prefsProvider),
        remaining,
        nextActive['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        profiles = remaining;
        activeProfileId = nextActive['id'] as String;
        form = _copyProfile(nextActive);
        saving = false;
        status = 'Profile deleted.';
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _loadProfiles, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final current = form;
    if (current == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profiles'),
        const SizedBox(height: 8),
        const Text('Profiles are saved locally on this device.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: profiles.map((profile) {
            final id = profile['id'] as String;
            return ChoiceChip(
              label: Text(profile['name'] as String),
              selected: id == activeProfileId,
              onSelected: saving ? null : (_) => _selectProfile(id),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newProfileController,
                decoration: const InputDecoration(
                  labelText: 'New profile name',
                  border: OutlineInputBorder(),
                ),
                maxLength: 40,
                onChanged: (value) => setState(() => newProfileName = value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Add profile',
              onPressed: saving ? null : () => _addProfile(),
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(current['id']),
          initialValue: current['name'] as String,
          decoration: const InputDecoration(
            labelText: 'Profile name',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
          onChanged: (value) => _setField('name', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey('${current['id']}-age'),
          initialValue: '${current['age']}',
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final age = int.tryParse(value);
            if (age != null && age > 0) _setField('age', age);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // Keep the deprecated argument for compatibility with the Flutter 3.3 minimum.
          // ignore: deprecated_member_use
          value: current['fitness'] as String,
          decoration: const InputDecoration(
            labelText: 'Fitness level',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
            DropdownMenuItem(value: 'high', child: Text('High')),
          ],
          onChanged: (value) {
            if (value != null) _setField('fitness', value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // Keep the deprecated argument for compatibility with the Flutter 3.3 minimum.
          // ignore: deprecated_member_use
          value: current['commute_mode'] as String,
          decoration: const InputDecoration(
            labelText: 'Commute mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'walk', child: Text('Walk')),
            DropdownMenuItem(value: 'cycle', child: Text('Cycle')),
            DropdownMenuItem(value: 'bus', child: Text('Bus')),
            DropdownMenuItem(value: 'metro', child: Text('Metro')),
            DropdownMenuItem(value: 'car', child: Text('Car')),
            DropdownMenuItem(value: 'car with AC', child: Text('Car with AC')),
            DropdownMenuItem(value: 'auto', child: Text('Auto')),
          ],
          onChanged: (value) {
            if (value != null) _setField('commute_mode', value);
          },
        ),
        const SizedBox(height: 12),
        _numberField(
          key: '${current['id']}-commute',
          label: 'Commute (minutes per day)',
          value: current['commute_minutes'] as int,
          onChanged: (value) => _setField('commute_minutes', value),
        ),
        const SizedBox(height: 12),
        _numberField(
          key: '${current['id']}-outdoor',
          label: 'Outdoor time (minutes per day)',
          value: current['outdoor_minutes'] as int,
          onChanged: (value) => _setField('outdoor_minutes', value),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Respiratory sensitivity'),
          value: (current['sensitivities'] as List).contains('respiratory'),
          onChanged: (value) => _toggleSensitivity('respiratory', value),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cardiac sensitivity'),
          value: (current['sensitivities'] as List).contains('cardiac'),
          onChanged: (value) => _toggleSensitivity('cardiac', value),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allergy sensitivity'),
          value: (current['sensitivities'] as List).contains('allergy'),
          onChanged: (value) => _toggleSensitivity('allergy', value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I use an air purifier at home'),
          value: current['has_purifier'] as bool,
          onChanged: (value) => _setField('has_purifier', value),
        ),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(status!),
          ),
        Row(
          children: [
            if (profiles.length > 1)
              TextButton.icon(
                onPressed: saving ? null : _deleteProfile,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete profile'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _saveCurrentProfile();
                      } catch (exception) {
                        if (mounted) {
                          setState(() => error = exception.toString());
                        }
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numberField({
    required String key,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(key),
      initialValue: '$value',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final parsed = int.tryParse(value);
        if (parsed != null && parsed >= 0) onChanged(parsed);
      },
    );
  }

  void _toggleSensitivity(String sensitivity, bool? selected) {
    final current = List<String>.from(form?['sensitivities'] as List? ?? []);
    if (selected == true && !current.contains(sensitivity)) {
      current.add(sensitivity);
    } else {
      current.remove(sensitivity);
    }
    _setField('sensitivities', current);
  }
}
