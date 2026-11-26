import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

typedef CitySelection = Future<void> Function(Map<String, dynamic> city);

class CitySearch extends ConsumerStatefulWidget {
  const CitySearch({
    required this.onSelect,
    this.selectedCity,
    this.label = 'City',
    super.key,
  });

  final CitySelection onSelect;
  final Map<String, dynamic>? selectedCity;
  final String label;

  @override
  ConsumerState<CitySearch> createState() => _CitySearchState();
}

class _CitySearchState extends ConsumerState<CitySearch> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> matches = [];
  String? message;
  bool searching = false;

  @override
  void initState() {
    super.initState();
    _controller.text = _selectedCityLabel;
  }

  @override
  void didUpdateWidget(covariant CitySearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cityLabel(oldWidget.selectedCity) != _selectedCityLabel) {
      _controller.text = _selectedCityLabel;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      searching = true;
      matches = [];
      message = null;
    });
    try {
      final response = await ref
          .read(apiProvider)
          .get('/location/search', queryParameters: {'q': query});
      if (response.data is! List) {
        throw const FormatException(
            'The city search returned invalid results.');
      }
      final results = (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      if (results.length == 1) {
        await _choose(results.single);
      } else {
        setState(() {
          matches = results;
          searching = false;
          if (results.isEmpty) message = 'No matching city was found.';
        });
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        searching = false;
        message = 'Could not search cities: $exception';
      });
    }
  }

  Future<void> _choose(Map<String, dynamic> city) async {
    setState(() {
      searching = true;
      message = null;
    });
    try {
      await widget.onSelect(city);
      if (!mounted) return;
      setState(() {
        _controller.text = _cityLabel(city);
        matches = [];
        searching = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        searching = false;
        message = 'Could not save this city: $exception';
      });
    }
  }

  String _cityLabel(Map<String, dynamic>? city) {
    if (city == null) return '';
    final name = city['name']?.toString() ?? 'Selected city';
    final country = city['country']?.toString();
    return country == null || country.isEmpty ? name : '$name, $country';
  }

  String get _selectedCityLabel => _cityLabel(widget.selectedCity);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Search city',
                onPressed: searching ? null : _search,
                icon: searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
          if (matches.isNotEmpty)
            ...matches.map(
              (city) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_cityLabel(city)),
                trailing: const Icon(Icons.chevron_right),
                onTap: searching ? null : () => _choose(city),
              ),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
}
