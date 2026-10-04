import 'package:flutter/material.dart';
import 'package:google_places_kit/google_places_kit.dart';

import 'common.dart';

/// Nearby search by type, and text search around a location.
class NearbyTab extends StatefulWidget {
  const NearbyTab({super.key});

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab>
    with AutomaticKeepAliveClientMixin {
  static const _types = {
    'restaurant': ('Restaurants', Icons.restaurant),
    'cafe': ('Cafés', Icons.local_cafe_outlined),
    'atm': ('ATMs', Icons.local_atm),
    'hospital': ('Hospitals', Icons.local_hospital_outlined),
    'pharmacy': ('Pharmacies', Icons.local_pharmacy_outlined),
    'gas_station': ('Gas', Icons.local_gas_station_outlined),
  };

  // Only what the list shows: Google bills by the most expensive field.
  static const _listFields = [
    PlaceField.id,
    PlaceField.displayName,
    PlaceField.shortAddress,
    PlaceField.location,
    PlaceField.rating,
    PlaceField.userRatingCount,
    PlaceField.currentOpeningHours,
  ];

  final _query = TextEditingController();
  Coordinates? _center;
  String? _centerName;
  String _type = 'restaurant';
  List<Place>? _results;
  PlacesException? _error;
  var _loading = false;
  var _textSearch = false; // the results came from the text search

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    final location = await currentLocation(context);
    if (location == null) return;
    setState(() {
      _center = location;
      _centerName = 'My location';
    });
    await _searchNearby();
  }

  Future<void> _pickArea() async {
    final place = await showPlaceSearch(context, hintText: 'Search near…');
    if (place?.location == null) return;
    setState(() {
      _center = place!.location;
      _centerName = place.name;
    });
    await _searchNearby();
  }

  Future<void> _run(
    Future<List<Place>> Function() search, {
    bool text = false,
  }) async {
    setState(() {
      _textSearch = text;
      _loading = true;
      _error = null;
    });
    try {
      final results = await search();
      setState(() => _results = results);
    } on PlacesException catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchNearby() => _run(
    () => GooglePlaces.instance.searchNearby(
      LocationArea.circle(_center!, 2000),
      includedTypes: [_type],
      fields: _listFields,
      maxResults: 20,
      rankByDistance: true,
    ),
  );

  Future<void> _searchText() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _run(
      () => GooglePlaces.instance.searchText(
        query,
        fields: _listFields,
        locationBias: _center == null
            ? null
            : LocationArea.circle(_center!, 5000),
        maxResults: 20,
      ),
      text: true,
    );
  }

  Future<void> _openPlace(Place place) async {
    try {
      // Everything the package reads, to show the full model.
      final details = await GooglePlaces.instance.details(
        place.id,
        fields: PlaceField.all,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [PlaceCard(place: details)],
          ),
        ),
      );
    } on PlacesException catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final results = _results;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card.outlined(
          child: ListTile(
            leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
            title: Text(_centerName ?? 'Choose where to search'),
            subtitle: Text(
              _center == null
                  ? 'Your location or any place'
                  : formatCoordinates(_center!),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Use my location',
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.gps_fixed),
                ),
                IconButton(
                  tooltip: 'Search near a place',
                  onPressed: _pickArea,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(key: type, value: (label, icon))
                in _types.entries)
              ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                selected: _type == type,
                onSelected: (_) {
                  setState(() => _type = type);
                  if (_center != null) _searchNearby();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchText(),
          decoration: InputDecoration(
            hintText: 'Or search, e.g. "pizza" or "gas station"',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.arrow_forward),
              onPressed: _searchText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ErrorBanner(_error!),
        if (results != null && results.isEmpty && !_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nothing found here.', textAlign: TextAlign.center),
          ),
        if (results != null)
          for (final place in results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  _textSearch ? Icons.place_outlined : _types[_type]!.$2,
                ),
              ),
              title: Text(place.name ?? ''),
              subtitle: Text(
                [
                  if (place.rating != null) '★ ${place.rating}',
                  if (place.openNow != null) place.openNow! ? 'Open' : 'Closed',
                  place.shortAddress ?? '',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _center == null || place.location == null
                  ? null
                  : Text(formatDistance(_center!.distanceTo(place.location!))),
              onTap: () => _openPlace(place),
            ),
        if (results != null && results.isNotEmpty)
          const GoogleMapsAttribution(),
      ],
    );
  }
}
