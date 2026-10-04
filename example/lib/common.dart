import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_kit/google_places_kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// The device's location, or null after showing why it isn't available.
Future<Coordinates?> currentLocation(BuildContext context) async {
  void say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      say('Turn on location to use this.');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      say('Location permission was not given.');
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    return Coordinates(position.latitude, position.longitude);
  } catch (e) {
    say('Could not get the location: $e');
    return null;
  }
}

/// Build with `--dart-define=SHOW_PHOTOS=false` to leave place photos out,
/// for example for screenshots.
const showPhotos = bool.fromEnvironment('SHOW_PHOTOS', defaultValue: true);

Future<void> openLink(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

String formatCoordinates(Coordinates c) =>
    '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}';

/// Shows a [PlacesException] the way an app could: the plain-words message,
/// with Google's own message below it.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.error, {super.key});

  final PlacesException error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
        title: Text(
          '${error.code.name}: ${error.message}',
          style: TextStyle(color: colors.onErrorContainer),
        ),
        subtitle: error.serverMessage == null
            ? null
            : Text(
                error.serverMessage!,
                style: TextStyle(color: colors.onErrorContainer),
              ),
      ),
    );
  }
}

/// A place page: photo, name, rating, opening hours, address and contact.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place});

  final Place place;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = place.addressComponents;
    final photo = place.photos.isEmpty || !showPhotos
        ? null
        : place.photos.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keyed, so a new place loads its own photo.
          if (photo != null) _Photo(key: ValueKey(photo.name), photo: photo),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name ?? '', style: theme.textTheme.titleLarge),
                if (place.primaryTypeLabel != null)
                  Text(
                    place.primaryTypeLabel!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (place.rating != null)
                      Chip(
                        avatar: const Icon(Icons.star, color: Colors.amber),
                        label: Text(
                          '${place.rating} (${place.userRatingCount ?? 0})',
                        ),
                      ),
                    if (place.openNow != null)
                      Chip(
                        avatar: Icon(
                          place.openNow! ? Icons.schedule : Icons.block,
                          color: place.openNow! ? Colors.green : Colors.red,
                        ),
                        label: Text(place.openNow! ? 'Open now' : 'Closed'),
                      ),
                    if (place.priceLevel != null)
                      Chip(label: Text(_price(place.priceLevel!))),
                  ],
                ),
              ],
            ),
          ),
          if (place.generativeSummary case final summary?)
            _AiSummaryTile(summary: summary),
          if (place.formattedAddress != null)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(place.formattedAddress!),
              subtitle: _landmark(place),
            ),
          if (place.phoneNumber != null)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(place.phoneNumber!),
              onTap: () => openLink(
                'tel:${place.internationalPhoneNumber ?? place.phoneNumber}',
              ),
            ),
          if (place.websiteUri != null)
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(
                Uri.parse(place.websiteUri!).host,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => openLink(place.websiteUri!),
            ),
          if (place.location != null)
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(formatCoordinates(place.location!)),
              subtitle: const Text('Latitude, longitude'),
            ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in [
                    ('Area', address.area),
                    ('City', address.city),
                    ('State', address.state),
                    ('Postal code', address.postalCode),
                    ('Country', address.countryCode),
                  ])
                    if (value != null) Chip(label: Text('$label: $value')),
                ],
              ),
            ),
          if (place.openingHours?.weekdayDescriptions.isNotEmpty ?? false)
            ExpansionTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Opening hours'),
              children: [
                for (final day in place.openingHours!.weekdayDescriptions)
                  ListTile(dense: true, title: Text(day)),
              ],
            )
          else if (place.currentOpeningHours?.weekdayDescriptions.isNotEmpty ??
              false)
            ExpansionTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Opening hours'),
              children: [
                for (final day
                    in place.currentOpeningHours!.weekdayDescriptions)
                  ListTile(dense: true, title: Text(day)),
              ],
            ),
          if (_amenities(place) case final amenities when amenities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (icon, label) in amenities)
                    Chip(avatar: Icon(icon, size: 18), label: Text(label)),
                ],
              ),
            ),
          if (place.reviews.isNotEmpty)
            ExpansionTile(
              leading: const Icon(Icons.reviews_outlined),
              title: Text('Reviews (${place.reviews.length})'),
              children: [
                for (final review in place.reviews.take(3))
                  ListTile(
                    // Google requires the author's name with a review.
                    title: Text(
                      '${review.author.displayName} · '
                      '${'★' * (review.rating ?? 0).round()}',
                    ),
                    subtitle: Text(
                      '${review.relativeTime ?? ''}\n${review.text ?? ''}',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          if (place.googleMapsUri != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilledButton.tonalIcon(
                onPressed: () => openLink(place.googleMapsUri!),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Google Maps'),
              ),
            ),
          const GoogleMapsAttribution(),
        ],
      ),
    );
  }

  /// "Across the road from Sassoon Dock", from the address descriptor.
  static Widget? _landmark(Place place) {
    final landmarks = place.addressDescriptor?.landmarks ?? const [];
    if (landmarks.isEmpty) return null;
    final landmark = landmarks.first;
    final relation = switch (landmark.spatialRelationship) {
      'ACROSS_THE_ROAD' => 'Across the road from',
      'DOWN_THE_ROAD' => 'Down the road from',
      'AROUND_THE_CORNER' => 'Around the corner from',
      'BESIDE' => 'Beside',
      'BEHIND' => 'Behind',
      'WITHIN' => 'Inside',
      _ => 'Near',
    };
    return Text('$relation ${landmark.name}');
  }

  static List<(IconData, String)> _amenities(Place place) {
    final a = place.amenities;
    return [
      if (a.delivery ?? false) (Icons.delivery_dining, 'Delivery'),
      if (a.dineIn ?? false) (Icons.restaurant, 'Dine-in'),
      if (a.takeout ?? false) (Icons.takeout_dining, 'Takeaway'),
      if (a.servesVegetarianFood ?? false) (Icons.eco_outlined, 'Vegetarian'),
      if (a.reservable ?? false) (Icons.event_available, 'Reservations'),
      if (a.outdoorSeating ?? false) (Icons.deck_outlined, 'Outdoor seating'),
      if (a.goodForChildren ?? false) (Icons.child_care, 'Good for kids'),
      if (place.payment?.acceptsNfc ?? false) (Icons.contactless, 'Tap to pay'),
      if ((place.parking?.freeParkingLot ?? false) ||
          (place.parking?.freeStreetParking ?? false))
        (Icons.local_parking, 'Free parking'),
      if (place.accessibility?.wheelchairAccessibleEntrance ?? false)
        (Icons.accessible, 'Wheelchair entrance'),
    ];
  }

  static String _price(PriceLevel level) => switch (level) {
    PriceLevel.free => 'Free',
    PriceLevel.inexpensive => 'Inexpensive',
    PriceLevel.moderate => 'Moderate',
    PriceLevel.expensive => 'Expensive',
    PriceLevel.veryExpensive => 'Very expensive',
  };
}

/// An AI summary, with the "Summarized with Gemini" label Google requires.
class _AiSummaryTile extends StatelessWidget {
  const _AiSummaryTile({required this.summary});

  final AiSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text(summary.text),
      subtitle: summary.disclosureText == null
          ? null
          : Text(
              summary.disclosureText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _Photo extends StatefulWidget {
  const _Photo({super.key, required this.photo});

  final PlacePhoto photo;
  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late final Future<String> _url = GooglePlaces.instance.photoUrl(
    widget.photo,
    maxWidth: 800,
  );

  @override
  Widget build(BuildContext context) {
    final author = widget.photo.authorAttributions.isEmpty
        ? null
        : widget.photo.authorAttributions.first;
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: FutureBuilder(
            future: _url,
            builder: (context, snapshot) => snapshot.hasData
                ? Image.network(snapshot.data!, fit: BoxFit.cover)
                : ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
          ),
        ),
        // Google requires the photographer's name with the photo.
        if (author != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Photo: ${author.displayName}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
