import 'package:flutter/material.dart';
import 'package:google_places_kit/google_places_kit.dart';

import 'common.dart';

/// A search built only on [PlaceAutocompleteController]: every widget here
/// is the app's own. It pops with the picked place.
class CustomSearchPage extends StatefulWidget {
  const CustomSearchPage({super.key});

  @override
  State<CustomSearchPage> createState() => _CustomSearchPageState();
}

class _CustomSearchPageState extends State<CustomSearchPage> {
  late final _search = PlaceAutocompleteController(fields: PlaceField.details);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    final place = await _search.select(suggestion);
    if (place != null && mounted) Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your own UI')),
      body: ListenableBuilder(
        listenable: _search,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SearchBar(
              autoFocus: true,
              hintText: 'Where do you want to go?',
              leading: const Icon(Icons.flight_takeoff),
              trailing: [
                if (_search.loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
              onChanged: _search.search,
            ),
            const SizedBox(height: 16),
            if (_search.error case final error?) ErrorBanner(error),
            if (_search.suggestions.isEmpty && _search.query.isEmpty)
              Text(
                'This page uses PlaceAutocompleteController for the search '
                'logic and draws everything itself.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final suggestion in _search.suggestions)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pick(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            suggestion.mainText.characters.first.toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                highlightMatches(
                                  suggestion.mainText,
                                  suggestion.mainTextMatches,
                                  style: theme.textTheme.titleMedium,
                                  matchStyle: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (suggestion.secondaryText.isNotEmpty)
                                Text(
                                  suggestion.secondaryText,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            // Google requires this with results shown without a map.
            if (_search.suggestions.isNotEmpty) const GoogleMapsAttribution(),
          ],
        ),
      ),
    );
  }
}
