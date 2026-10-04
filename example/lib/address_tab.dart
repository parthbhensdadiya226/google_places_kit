import 'package:flutter/material.dart';
import 'package:google_places_kit/google_places_kit.dart';

import 'common.dart';

/// Geocoding: latitude/longitude to address, and address to coordinates.
class AddressTab extends StatefulWidget {
  const AddressTab({super.key});

  @override
  State<AddressTab> createState() => _AddressTabState();
}

class _AddressTabState extends State<AddressTab>
    with AutomaticKeepAliveClientMixin {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _address = TextEditingController();
  var _toAddress = true;
  List<GeocodingResult>? _results;
  PlacesException? _error;
  var _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _run(Future<List<GeocodingResult>> Function() request) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await request();
      setState(() => _results = results);
    } on PlacesException catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _useMyLocation() async {
    final location = await currentLocation(context);
    if (location == null) return;
    _latitude.text = location.latitude.toStringAsFixed(6);
    _longitude.text = location.longitude.toStringAsFixed(6);
    await _findAddress();
  }

  Future<void> _findAddress() async {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a latitude and a longitude.')),
      );
      return;
    }
    await _run(
      () => GooglePlaces.instance.reverseGeocode(
        Coordinates(latitude, longitude),
      ),
    );
  }

  Future<void> _findCoordinates() async {
    final address = _address.text.trim();
    if (address.isEmpty) return;
    await _run(() => GooglePlaces.instance.geocode(address));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final results = _results;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.pin_drop_outlined),
              label: Text('Lat/lng → Address'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.my_location),
              label: Text('Address → Lat/lng'),
            ),
          ],
          selected: {_toAddress},
          onSelectionChanged: (value) => setState(() {
            _toAddress = value.single;
            _results = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_toAddress) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('My location'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _findAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('Find address'),
                ),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _address,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _findCoordinates(),
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'e.g. 350 5th Ave, New York',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _findCoordinates,
            icon: const Icon(Icons.search),
            label: const Text('Find coordinates'),
          ),
        ],
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ErrorBanner(_error!),
        if (results != null && results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No address found.', textAlign: TextAlign.center),
          ),
        if (results != null && results.isNotEmpty) ...[
          _ResultCard(result: results.first),
          if (results.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Other matches',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final result in results.skip(1).take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(result.formattedAddress),
                subtitle: Text(result.types.join(', ')),
              ),
          ],
          const GoogleMapsAttribution(),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final GeocodingResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = result.addressComponents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.formattedAddress, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              formatCoordinates(result.location),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 24),
            for (final (label, value) in [
              ('Street', [parts.streetNumber, parts.street].nonNulls.join(' ')),
              ('Area', parts.area),
              ('City', parts.city),
              ('District', parts.district),
              ('State', parts.state),
              ('Postal code', parts.postalCode),
              (
                'Country',
                '${parts.country ?? ''} (${parts.countryCode ?? ''})',
              ),
              ('Accuracy', result.locationType?.name),
            ])
              if (value != null && value.isNotEmpty && value != ' ()')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: Text(value)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
