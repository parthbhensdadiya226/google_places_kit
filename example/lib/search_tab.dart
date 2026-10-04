import 'package:flutter/material.dart';
import 'package:google_places_kit/google_places_kit.dart';

import 'common.dart';
import 'custom_search_page.dart';

/// Autocomplete: the inline field and the full-screen search.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab>
    with AutomaticKeepAliveClientMixin {
  Place? _place;
  PlacesException? _error;

  @override
  bool get wantKeepAlive => true;

  void _show(Place place) => setState(() {
    _place = place;
    _error = null;
  });

  Future<void> _openFullScreen() async {
    final place = await showPlaceSearch(context, fields: PlaceField.details);
    if (place != null) _show(place);
  }

  Future<void> _openCustom() async {
    final place = await Navigator.of(context)
        .push<Place>(MaterialPageRoute(builder: (_) => CustomSearchPage()));
    if (place != null) _show(place);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlaceAutocompleteField(
          fields: PlaceField.details,
          onSelected: _show,
          onError: (e) => setState(() => _error = e),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _openFullScreen,
              icon: const Icon(Icons.open_in_full),
              label: const Text('Full-screen search'),
            ),
            TextButton.icon(
              onPressed: _openCustom,
              icon: const Icon(Icons.brush_outlined),
              label: const Text('Your own UI'),
            ),
          ],
        ),
        if (_error != null) ErrorBanner(_error!),
        if (_place != null)
          PlaceCard(place: _place!)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.travel_explore,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Search for any place, address or business',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a suggestion to see its details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
