import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

// Common types ---------------------------------------------------------------

/// A point on the earth, in degrees.
@immutable
class Coordinates {
  /// Creates coordinates from a [latitude] and a [longitude], in degrees.
  const Coordinates(this.latitude, this.longitude);

  /// Reads `{"latitude": .., "longitude": ..}` (Places) or
  /// `{"lat": .., "lng": ..}` (Geocoding).
  factory Coordinates.fromJson(Map<String, Object?> json) => Coordinates(
    _double(json['latitude'] ?? json['lat']) ?? 0,
    _double(json['longitude'] ?? json['lng']) ?? 0,
  );

  /// Degrees north (positive) or south (negative) of the equator.
  final double latitude;

  /// Degrees east (positive) or west (negative) of Greenwich.
  final double longitude;

  /// The straight-line distance to [other] in meters (haversine formula).
  double distanceTo(Coordinates other) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(a));
  }

  /// The JSON the Places API expects.
  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  bool operator ==(Object other) =>
      other is Coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Coordinates($latitude, $longitude)';
}

/// An area on the map: a circle or a rectangle. Used to bias or restrict
/// results to a place, such as the user's city.
@immutable
class LocationArea {
  /// A circle of [radiusMeters] around [center]. Google accepts a radius of
  /// up to 50,000 meters.
  const LocationArea.circle(Coordinates this.center, double this.radiusMeters)
    : low = null,
      high = null;

  /// A rectangle from its south-west corner ([low]) to its north-east corner
  /// ([high]).
  const LocationArea.rectangle(Coordinates this.low, Coordinates this.high)
    : center = null,
      radiusMeters = null;

  /// The center of a circle, or null for a rectangle.
  final Coordinates? center;

  /// The radius of a circle in meters, or null for a rectangle.
  final double? radiusMeters;

  /// The south-west corner of a rectangle, or null for a circle.
  final Coordinates? low;

  /// The north-east corner of a rectangle, or null for a circle.
  final Coordinates? high;

  /// The JSON the Places API expects.
  Map<String, Object?> toJson() => center != null
      ? {
          'circle': {'center': center!.toJson(), 'radius': radiusMeters},
        }
      : {
          'rectangle': {'low': low!.toJson(), 'high': high!.toJson()},
        };
}

/// A rectangle on the map, such as the area to show for a place.
@immutable
class Viewport {
  /// Creates a viewport from its south-west ([low]) and north-east ([high])
  /// corners.
  const Viewport(this.low, this.high);

  /// Reads `{"low", "high"}` (Places) or `{"southwest", "northeast"}`
  /// (Geocoding).
  factory Viewport.fromJson(Map<String, Object?> json) => Viewport(
    Coordinates.fromJson(_map(json['low'] ?? json['southwest'])),
    Coordinates.fromJson(_map(json['high'] ?? json['northeast'])),
  );

  /// The south-west corner.
  final Coordinates low;

  /// The north-east corner.
  final Coordinates high;

  /// The middle of the rectangle.
  Coordinates get center => Coordinates(
    (low.latitude + high.latitude) / 2,
    (low.longitude + high.longitude) / 2,
  );

  /// As a [LocationArea], to search inside it.
  LocationArea toArea() => LocationArea.rectangle(low, high);
}

/// A plus code: a short code for a location, usable where there are no
/// street addresses.
@immutable
class PlusCode {
  /// Creates a plus code.
  const PlusCode({required this.globalCode, this.compoundCode});

  /// Reads the Places format (`globalCode`) and the Geocoding format
  /// (`global_code`).
  factory PlusCode.fromJson(Map<String, Object?> json) => PlusCode(
    globalCode: (json['globalCode'] ?? json['global_code'] ?? '') as String,
    compoundCode: (json['compoundCode'] ?? json['compound_code']) as String?,
  );

  /// The full code, such as "7JCJWRCM+QV".
  final String globalCode;

  /// The short code with the area, such as "WRCM+QV Mumbai, Maharashtra,
  /// India".
  final String? compoundCode;

  @override
  String toString() => globalCode;
}

/// An amount of money.
@immutable
class Money {
  /// Creates an amount.
  const Money({required this.currencyCode, required this.amount});

  /// Reads Google's `{"currencyCode", "units", "nanos"}`.
  factory Money.fromJson(Map<String, Object?> json) => Money(
    currencyCode: (json['currencyCode'] ?? '') as String,
    amount:
        (num.tryParse('${json['units'] ?? 0}') ?? 0) +
        ((json['nanos'] as num?) ?? 0) / 1e9,
  );

  /// The ISO 4217 currency code, such as "INR" or "USD".
  final String currencyCode;

  /// The amount, such as 104.21.
  final num amount;

  @override
  String toString() => '$amount $currencyCode';
}

/// One part of an address, such as the city or the postal code.
@immutable
class AddressComponent {
  /// Creates an address component.
  const AddressComponent({
    required this.longText,
    required this.shortText,
    required this.types,
    this.languageCode,
  });

  /// Reads the Places format (`longText`) and the Geocoding format
  /// (`long_name`).
  factory AddressComponent.fromJson(Map<String, Object?> json) =>
      AddressComponent(
        longText: (json['longText'] ?? json['long_name'] ?? '') as String,
        shortText: (json['shortText'] ?? json['short_name'] ?? '') as String,
        types: _strings(json['types']),
        languageCode: json['languageCode'] as String?,
      );

  /// The full text, such as "Maharashtra" or "India".
  final String longText;

  /// The short text, such as "MH" or "IN".
  final String shortText;

  /// What this part is, such as `locality` (city) or `postal_code`. See
  /// Google's address types.
  final List<String> types;

  /// The language of the text, such as "en" (Places only).
  final String? languageCode;

  @override
  String toString() => 'AddressComponent($longText, $types)';
}

/// Easy access to the usual address parts.
///
/// ```dart
/// final address = place.addressComponents;
/// print('${address.city}, ${address.state} ${address.postalCode}');
/// ```
extension AddressParts on List<AddressComponent> {
  /// The first component of [type], such as `locality`.
  AddressComponent? ofType(String type) {
    for (final component in this) {
      if (component.types.contains(type)) return component;
    }
    return null;
  }

  /// House or building number.
  String? get streetNumber => ofType('street_number')?.longText;

  /// Street name.
  String? get street => ofType('route')?.longText;

  /// Building or premise name.
  String? get premise => ofType('premise')?.longText;

  /// Neighbourhood or area within the city.
  String? get area =>
      (ofType('sublocality_level_1') ?? ofType('sublocality'))?.longText;

  /// City or town.
  String? get city => (ofType('locality') ?? ofType('postal_town'))?.longText;

  /// District, county or similar (second-level administrative area).
  String? get district => ofType('administrative_area_level_2')?.longText;

  /// State or province.
  String? get state => ofType('administrative_area_level_1')?.longText;

  /// Short state code, such as "MH" or "CA", when Google has one.
  String? get stateCode => ofType('administrative_area_level_1')?.shortText;

  /// Postal or ZIP code.
  String? get postalCode => ofType('postal_code')?.longText;

  /// Country name.
  String? get country => ofType('country')?.longText;

  /// Two-letter country code (ISO 3166-1), such as "IN" or "US".
  String? get countryCode => ofType('country')?.shortText;
}

/// A postal address in the standard format, ready for a shipping form.
@immutable
class PostalAddress {
  /// Creates a postal address.
  const PostalAddress({
    this.regionCode,
    this.languageCode,
    this.postalCode,
    this.administrativeArea,
    this.locality,
    this.sublocality,
    this.addressLines = const [],
    this.organization,
  });

  /// Reads a postal address from the Places API.
  factory PostalAddress.fromJson(Map<String, Object?> json) => PostalAddress(
    regionCode: json['regionCode'] as String?,
    languageCode: json['languageCode'] as String?,
    postalCode: json['postalCode'] as String?,
    administrativeArea: json['administrativeArea'] as String?,
    locality: json['locality'] as String?,
    sublocality: json['sublocality'] as String?,
    addressLines: _strings(json['addressLines']),
    organization: json['organization'] as String?,
  );

  /// Two-letter country code, such as "IN".
  final String? regionCode;

  /// The address language, such as "en-US".
  final String? languageCode;

  /// Postal or ZIP code.
  final String? postalCode;

  /// State or province.
  final String? administrativeArea;

  /// City or town.
  final String? locality;

  /// Area within the city.
  final String? sublocality;

  /// The street lines, such as ["Ground Floor, Oxford Center", "Shahid
  /// Bhagat Singh Rd"].
  final List<String> addressLines;

  /// The business name, if part of the address.
  final String? organization;
}

// Autocomplete ---------------------------------------------------------------

/// A part of a suggestion's text that matches what the user typed, as
/// character offsets. Use it to show the match in bold.
@immutable
class TextMatch {
  /// Creates a match from [start] (inclusive) to [end] (exclusive).
  const TextMatch(this.start, this.end);

  /// Reads `{"startOffset", "endOffset"}`.
  factory TextMatch.fromJson(Map<String, Object?> json) => TextMatch(
    (json['startOffset'] as int?) ?? 0,
    (json['endOffset'] as int?) ?? 0,
  );

  /// The first matching character.
  final int start;

  /// The character after the match.
  final int end;
}

/// One suggestion from [GooglePlaces.autocomplete].
@immutable
class PlaceSuggestion {
  /// Creates a suggestion.
  const PlaceSuggestion({
    required this.placeId,
    required this.text,
    required this.mainText,
    required this.secondaryText,
    this.textMatches = const [],
    this.mainTextMatches = const [],
    this.secondaryTextMatches = const [],
    this.types = const [],
    this.distanceMeters,
  });

  /// Reads a `placePrediction` from the Places API.
  factory PlaceSuggestion.fromJson(Map<String, Object?> json) {
    final format = _map(json['structuredFormat']);
    final text = _text(json['text']) ?? '';
    return PlaceSuggestion(
      placeId: (json['placeId'] ?? '') as String,
      text: text,
      mainText: _text(format['mainText']) ?? text,
      secondaryText: _text(format['secondaryText']) ?? '',
      textMatches: _matches(json['text']),
      mainTextMatches: _matches(format['mainText']),
      secondaryTextMatches: _matches(format['secondaryText']),
      types: _strings(json['types']),
      distanceMeters: json['distanceMeters'] as int?,
    );
  }

  /// Pass it to [GooglePlaces.details] for the full place.
  final String placeId;

  /// The full text, such as "Gateway Of India, Apollo Bandar, Mumbai, India".
  final String text;

  /// The name, such as "Gateway Of India". Show it in bold.
  final String mainText;

  /// The rest, such as "Apollo Bandar, Colaba, Mumbai, India".
  final String secondaryText;

  /// Where [text] matches the input.
  final List<TextMatch> textMatches;

  /// Where [mainText] matches the input.
  final List<TextMatch> mainTextMatches;

  /// Where [secondaryText] matches the input.
  final List<TextMatch> secondaryTextMatches;

  /// The place types, such as `restaurant` and `food`.
  final List<String> types;

  /// The distance from the `origin` passed to the request, in meters.
  final int? distanceMeters;

  @override
  String toString() => 'PlaceSuggestion($placeId, $text)';
}

// Place ----------------------------------------------------------------------

/// A place from [GooglePlaces.details], [GooglePlaces.searchText] or
/// [GooglePlaces.searchNearby].
///
/// Only the fields you asked for (see [PlaceField]) are set; the rest are
/// null or empty.
@immutable
class Place {
  /// Creates a place.
  const Place({
    required this.id,
    this.name,
    this.formattedAddress,
    this.shortAddress,
    this.adrFormatAddress,
    this.postalAddress,
    this.addressComponents = const [],
    this.addressDescriptor,
    this.location,
    this.viewport,
    this.plusCode,
    this.types = const [],
    this.primaryType,
    this.primaryTypeLabel,
    this.googleMapsTypeLabel,
    this.iconMaskBaseUri,
    this.iconBackgroundColor,
    this.businessStatus,
    this.pureServiceAreaBusiness,
    this.googleMapsUri,
    this.googleMapsLinks,
    this.phoneNumber,
    this.internationalPhoneNumber,
    this.websiteUri,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.priceRange,
    this.openingHours,
    this.currentOpeningHours,
    this.secondaryOpeningHours = const [],
    this.currentSecondaryOpeningHours = const [],
    this.utcOffsetMinutes,
    this.timeZone,
    this.editorialSummary,
    this.generativeSummary,
    this.reviewSummary,
    this.photos = const [],
    this.reviews = const [],
    this.amenities = const PlaceAmenities(),
    this.accessibility,
    this.parking,
    this.payment,
    this.fuelOptions,
    this.evChargeOptions,
    this.navigationPoints = const [],
    this.containingPlaceIds = const [],
    this.subDestinationIds = const [],
    this.json = const {},
  });

  /// Reads a place from the Places API.
  factory Place.fromJson(Map<String, Object?> json) => Place(
    id: (json['id'] ?? '') as String,
    name: _text(json['displayName']),
    formattedAddress: json['formattedAddress'] as String?,
    shortAddress: json['shortFormattedAddress'] as String?,
    adrFormatAddress: json['adrFormatAddress'] as String?,
    postalAddress: _object(json['postalAddress'], PostalAddress.fromJson),
    addressComponents: _objects(
      json['addressComponents'],
      AddressComponent.fromJson,
    ),
    addressDescriptor: _object(
      json['addressDescriptor'],
      AddressDescriptor.fromJson,
    ),
    location: _object(json['location'], Coordinates.fromJson),
    viewport: _object(json['viewport'], Viewport.fromJson),
    plusCode: _object(json['plusCode'], PlusCode.fromJson),
    types: _strings(json['types']),
    primaryType: json['primaryType'] as String?,
    primaryTypeLabel: _text(json['primaryTypeDisplayName']),
    googleMapsTypeLabel: _text(json['googleMapsTypeLabel']),
    iconMaskBaseUri: json['iconMaskBaseUri'] as String?,
    iconBackgroundColor: json['iconBackgroundColor'] as String?,
    businessStatus: _businessStatuses[json['businessStatus']],
    pureServiceAreaBusiness: json['pureServiceAreaBusiness'] as bool?,
    googleMapsUri: json['googleMapsUri'] as String?,
    googleMapsLinks: _object(json['googleMapsLinks'], GoogleMapsLinks.fromJson),
    phoneNumber: json['nationalPhoneNumber'] as String?,
    internationalPhoneNumber: json['internationalPhoneNumber'] as String?,
    websiteUri: json['websiteUri'] as String?,
    rating: _double(json['rating']),
    userRatingCount: json['userRatingCount'] as int?,
    priceLevel: _priceLevels[json['priceLevel']],
    priceRange: _object(json['priceRange'], PriceRange.fromJson),
    openingHours: _object(json['regularOpeningHours'], OpeningHours.fromJson),
    currentOpeningHours: _object(
      json['currentOpeningHours'],
      OpeningHours.fromJson,
    ),
    secondaryOpeningHours: _objects(
      json['regularSecondaryOpeningHours'],
      OpeningHours.fromJson,
    ),
    currentSecondaryOpeningHours: _objects(
      json['currentSecondaryOpeningHours'],
      OpeningHours.fromJson,
    ),
    utcOffsetMinutes: json['utcOffsetMinutes'] as int?,
    timeZone: _map(json['timeZone'])['id'] as String?,
    editorialSummary: _text(json['editorialSummary']),
    generativeSummary: _object(json['generativeSummary'], AiSummary.fromJson),
    reviewSummary: _object(json['reviewSummary'], AiSummary.fromJson),
    photos: _objects(json['photos'], PlacePhoto.fromJson),
    reviews: _objects(json['reviews'], PlaceReview.fromJson),
    amenities: PlaceAmenities.fromJson(json),
    accessibility: _object(
      json['accessibilityOptions'],
      AccessibilityOptions.fromJson,
    ),
    parking: _object(json['parkingOptions'], ParkingOptions.fromJson),
    payment: _object(json['paymentOptions'], PaymentOptions.fromJson),
    fuelOptions: _object(json['fuelOptions'], FuelOptions.fromJson),
    evChargeOptions: _object(json['evChargeOptions'], EvChargeOptions.fromJson),
    navigationPoints: _objects(
      json['navigationPoints'],
      NavigationPoint.fromJson,
    ),
    containingPlaceIds: [
      for (final p in _list(json['containingPlaces']))
        if (_map(p)['id'] case final String id) id,
    ],
    subDestinationIds: [
      for (final p in _list(json['subDestinations']))
        if (_map(p)['id'] case final String id) id,
    ],
    json: json,
  );

  /// The place ID. Store it to get the place again later.
  final String id;

  /// The name, such as "Gateway Of India Mumbai".
  final String? name;

  /// The full address.
  final String? formattedAddress;

  /// A shorter address, without the country and postal code.
  final String? shortAddress;

  /// The address in adr microformat (HTML with `<span class="...">`).
  final String? adrFormatAddress;

  /// The address in the standard postal format.
  final PostalAddress? postalAddress;

  /// The address split into parts. Use [AddressParts] for the city, state,
  /// postal code and country.
  final List<AddressComponent> addressComponents;

  /// Nearby landmarks and the areas the place is in, such as "across the
  /// road from Sassoon Dock".
  final AddressDescriptor? addressDescriptor;

  /// Where the place is.
  final Coordinates? location;

  /// The area to show on a map.
  final Viewport? viewport;

  /// The plus code.
  final PlusCode? plusCode;

  /// All types, such as `restaurant` and `food`.
  final List<String> types;

  /// The main type, such as `pizza_restaurant`.
  final String? primaryType;

  /// The main type in words, such as "Pizza restaurant", in the request's
  /// language.
  final String? primaryTypeLabel;

  /// The type label Google Maps shows, such as "Pizza Restaurant".
  final String? googleMapsTypeLabel;

  /// The base URL of the place's icon. Add `.svg` or `.png`.
  final String? iconMaskBaseUri;

  /// The icon's background color, such as "#FF9E67".
  final String? iconBackgroundColor;

  /// Whether it is open for business at all.
  final BusinessStatus? businessStatus;

  /// True for businesses that only visit customers, such as plumbers, and
  /// have no shop to go to.
  final bool? pureServiceAreaBusiness;

  /// A link that opens the place in Google Maps.
  final String? googleMapsUri;

  /// Links to directions, reviews, photos and writing a review in Google
  /// Maps.
  final GoogleMapsLinks? googleMapsLinks;

  /// The phone number in local format.
  final String? phoneNumber;

  /// The phone number in international format, such as "+91 22 ...".
  final String? internationalPhoneNumber;

  /// The place's website.
  final String? websiteUri;

  /// The average rating, 1 to 5.
  final double? rating;

  /// How many ratings [rating] is based on.
  final int? userRatingCount;

  /// How expensive it is.
  final PriceLevel? priceLevel;

  /// The usual price range, such as ₹200–400.
  final PriceRange? priceRange;

  /// The usual weekly opening hours.
  final OpeningHours? openingHours;

  /// The opening hours for the coming week, including holidays.
  final OpeningHours? currentOpeningHours;

  /// Hours of parts of the place, such as the drive-through or delivery.
  /// See [OpeningHours.type].
  final List<OpeningHours> secondaryOpeningHours;

  /// [secondaryOpeningHours] for the coming week, including holidays.
  final List<OpeningHours> currentSecondaryOpeningHours;

  /// Whether it is open right now, if Google knows.
  bool? get openNow => currentOpeningHours?.openNow ?? openingHours?.openNow;

  /// The place's time zone offset from UTC, in minutes.
  final int? utcOffsetMinutes;

  /// The IANA time zone, such as "Asia/Calcutta".
  final String? timeZone;

  /// A short description from Google.
  final String? editorialSummary;

  /// An AI-generated overview of the place.
  final AiSummary? generativeSummary;

  /// An AI-generated summary of the reviews.
  final AiSummary? reviewSummary;

  /// Photos. Show them with [GooglePlaces.photoUrl].
  final List<PlacePhoto> photos;

  /// Up to five reviews.
  final List<PlaceReview> reviews;

  /// What the place offers, such as delivery or vegetarian food.
  final PlaceAmenities amenities;

  /// Wheelchair access.
  final AccessibilityOptions? accessibility;

  /// Parking.
  final ParkingOptions? parking;

  /// Accepted payment methods.
  final PaymentOptions? payment;

  /// Fuel prices, for petrol pumps.
  final FuelOptions? fuelOptions;

  /// Chargers, for EV charging stations.
  final EvChargeOptions? evChargeOptions;

  /// Where to stop when driving or walking to the place, such as an
  /// entrance on a side road.
  final List<NavigationPoint> navigationPoints;

  /// The IDs of places this place is in, such as the mall a shop is in.
  final List<String> containingPlaceIds;

  /// The IDs of places inside this place, such as an airport's terminals.
  final List<String> subDestinationIds;

  /// The raw JSON, for fields this class doesn't cover.
  final Map<String, Object?> json;

  @override
  String toString() => 'Place($id, $name)';
}

/// How expensive a place is.
enum PriceLevel {
  /// Free.
  free,

  /// Inexpensive.
  inexpensive,

  /// Moderately priced.
  moderate,

  /// Expensive.
  expensive,

  /// Very expensive.
  veryExpensive,
}

/// Whether a place is open for business.
enum BusinessStatus {
  /// Operating normally.
  operational,

  /// Closed for now.
  closedTemporarily,

  /// Closed for good.
  closedPermanently,
}

/// The usual price range of a place.
@immutable
class PriceRange {
  /// Creates a price range.
  const PriceRange({this.start, this.end});

  /// Reads a price range from the Places API.
  factory PriceRange.fromJson(Map<String, Object?> json) => PriceRange(
    start: _object(json['startPrice'], Money.fromJson),
    end: _object(json['endPrice'], Money.fromJson),
  );

  /// The low end.
  final Money? start;

  /// The high end. Null means "and up".
  final Money? end;
}

/// Opening hours of a place, or of a part of it (see [type]).
@immutable
class OpeningHours {
  /// Creates opening hours.
  const OpeningHours({
    this.openNow,
    this.periods = const [],
    this.weekdayDescriptions = const [],
    this.nextOpenTime,
    this.nextCloseTime,
    this.type,
  });

  /// Reads opening hours from the Places API.
  factory OpeningHours.fromJson(Map<String, Object?> json) => OpeningHours(
    openNow: json['openNow'] as bool?,
    periods: _objects(json['periods'], OpeningPeriod.fromJson),
    weekdayDescriptions: _strings(json['weekdayDescriptions']),
    nextOpenTime: _time(json['nextOpenTime']),
    nextCloseTime: _time(json['nextCloseTime']),
    type: json['secondaryHoursType'] as String?,
  );

  /// Whether it is open right now.
  final bool? openNow;

  /// When it opens and closes, as data.
  final List<OpeningPeriod> periods;

  /// One line per day, such as "Monday: 11:00 AM – 11:00 PM", in the
  /// request's language.
  final List<String> weekdayDescriptions;

  /// When it next opens (UTC), if it is closed now.
  final DateTime? nextOpenTime;

  /// When it next closes (UTC), if it is open now.
  final DateTime? nextCloseTime;

  /// For [Place.secondaryOpeningHours]: which part, such as `DRIVE_THROUGH`,
  /// `DELIVERY`, `TAKEOUT`, `KITCHEN` or `BREAKFAST`.
  final String? type;
}

/// One opening: from [open] to [close].
@immutable
class OpeningPeriod {
  /// Creates a period.
  const OpeningPeriod({required this.open, this.close});

  /// Reads a period from the Places API.
  factory OpeningPeriod.fromJson(Map<String, Object?> json) => OpeningPeriod(
    open: OpeningTime.fromJson(_map(json['open'])),
    close: _object(json['close'], OpeningTime.fromJson),
  );

  /// When it opens.
  final OpeningTime open;

  /// When it closes. Null means open 24 hours.
  final OpeningTime? close;
}

/// A time in the week, in the place's time zone.
@immutable
class OpeningTime {
  /// Creates a time.
  const OpeningTime({
    required this.day,
    required this.hour,
    required this.minute,
    this.date,
  });

  /// Reads a time from the Places API.
  factory OpeningTime.fromJson(Map<String, Object?> json) {
    final date = _map(json['date']);
    return OpeningTime(
      day: (json['day'] as int?) ?? 0,
      hour: (json['hour'] as int?) ?? 0,
      minute: (json['minute'] as int?) ?? 0,
      date: date.isEmpty
          ? null
          : DateTime(
              date['year'] as int,
              date['month'] as int,
              date['day'] as int,
            ),
    );
  }

  /// Day of the week: 0 is Sunday, 6 is Saturday.
  final int day;

  /// Hour, 0 to 23.
  final int hour;

  /// Minute, 0 to 59.
  final int minute;

  /// The date, in [Place.currentOpeningHours] only.
  final DateTime? date;
}

/// Who took a photo or wrote a review. Google requires you to show it next
/// to the photo or review.
@immutable
class AuthorAttribution {
  /// Creates an attribution.
  const AuthorAttribution({required this.displayName, this.uri, this.photoUri});

  /// Reads an attribution from the Places API.
  factory AuthorAttribution.fromJson(Map<String, Object?> json) =>
      AuthorAttribution(
        displayName: (json['displayName'] ?? '') as String,
        uri: json['uri'] as String?,
        photoUri: json['photoUri'] as String?,
      );

  /// The author's name.
  final String displayName;

  /// A link to the author's profile.
  final String? uri;

  /// The author's profile photo.
  final String? photoUri;
}

/// A photo of a place. Get an image URL for it with
/// [GooglePlaces.photoUrl].
@immutable
class PlacePhoto {
  /// Creates a photo reference.
  const PlacePhoto({
    required this.name,
    required this.widthPx,
    required this.heightPx,
    this.authorAttributions = const [],
    this.googleMapsUri,
    this.flagContentUri,
  });

  /// Reads a photo from the Places API.
  factory PlacePhoto.fromJson(Map<String, Object?> json) => PlacePhoto(
    name: (json['name'] ?? '') as String,
    widthPx: (json['widthPx'] ?? 0) as int,
    heightPx: (json['heightPx'] ?? 0) as int,
    authorAttributions: _objects(
      json['authorAttributions'],
      AuthorAttribution.fromJson,
    ),
    googleMapsUri: json['googleMapsUri'] as String?,
    flagContentUri: json['flagContentUri'] as String?,
  );

  /// The photo's resource name, such as `places/ChIJ.../photos/Aa...`.
  final String name;

  /// The largest available width, in pixels.
  final int widthPx;

  /// The largest available height, in pixels.
  final int heightPx;

  /// Who took the photo. Show it with the photo.
  final List<AuthorAttribution> authorAttributions;

  /// Opens the photo in Google Maps.
  final String? googleMapsUri;

  /// Where users can report a problem with the photo.
  final String? flagContentUri;
}

/// A review of a place.
@immutable
class PlaceReview {
  /// Creates a review.
  const PlaceReview({
    required this.author,
    this.rating,
    this.text,
    this.originalText,
    this.languageCode,
    this.relativeTime,
    this.publishTime,
    this.googleMapsUri,
    this.flagContentUri,
  });

  /// Reads a review from the Places API.
  factory PlaceReview.fromJson(Map<String, Object?> json) => PlaceReview(
    author: AuthorAttribution.fromJson(_map(json['authorAttribution'])),
    rating: _double(json['rating']),
    text: _text(json['text']),
    originalText: _text(json['originalText']),
    languageCode: _map(json['text'])['languageCode'] as String?,
    relativeTime: json['relativePublishTimeDescription'] as String?,
    publishTime: _time(json['publishTime']),
    googleMapsUri: json['googleMapsUri'] as String?,
    flagContentUri: json['flagContentUri'] as String?,
  );

  /// Who wrote it. Show it with the review.
  final AuthorAttribution author;

  /// Stars, 1 to 5.
  final double? rating;

  /// The review text, translated to the request's language if needed.
  final String? text;

  /// The text as the author wrote it.
  final String? originalText;

  /// The language of [text], such as "en".
  final String? languageCode;

  /// Such as "2 weeks ago", in the request's language.
  final String? relativeTime;

  /// When it was published (UTC).
  final DateTime? publishTime;

  /// Opens the review in Google Maps.
  final String? googleMapsUri;

  /// Where users can report the review.
  final String? flagContentUri;
}

/// An AI-generated summary of a place or of its reviews.
///
/// Google requires you to show [disclosureText] (such as "Summarized with
/// Gemini") with it.
@immutable
class AiSummary {
  /// Creates a summary.
  const AiSummary({
    required this.text,
    this.disclosureText,
    this.flagContentUri,
    this.reviewsUri,
  });

  /// Reads a `generativeSummary` or `reviewSummary`.
  factory AiSummary.fromJson(Map<String, Object?> json) => AiSummary(
    text: _text(json['overview'] ?? json['text']) ?? '',
    disclosureText: _text(json['disclosureText']),
    flagContentUri:
        (json['overviewFlagContentUri'] ?? json['flagContentUri']) as String?,
    reviewsUri: json['reviewsUri'] as String?,
  );

  /// The summary.
  final String text;

  /// The label to show with it, such as "Summarized with Gemini".
  final String? disclosureText;

  /// Where users can report a problem with the summary.
  final String? flagContentUri;

  /// For a review summary: opens the reviews in Google Maps.
  final String? reviewsUri;
}

/// Links that open a place in Google Maps.
@immutable
class GoogleMapsLinks {
  /// Creates the links.
  const GoogleMapsLinks({
    this.placeUri,
    this.directionsUri,
    this.reviewsUri,
    this.writeAReviewUri,
    this.photosUri,
  });

  /// Reads the links from the Places API.
  factory GoogleMapsLinks.fromJson(Map<String, Object?> json) =>
      GoogleMapsLinks(
        placeUri: json['placeUri'] as String?,
        directionsUri: json['directionsUri'] as String?,
        reviewsUri: json['reviewsUri'] as String?,
        writeAReviewUri: json['writeAReviewUri'] as String?,
        photosUri: json['photosUri'] as String?,
      );

  /// The place.
  final String? placeUri;

  /// Directions to the place.
  final String? directionsUri;

  /// The reviews.
  final String? reviewsUri;

  /// Write a review.
  final String? writeAReviewUri;

  /// The photos.
  final String? photosUri;
}

/// What a place offers. Each value is null when Google doesn't know.
@immutable
class PlaceAmenities {
  /// Creates amenities.
  const PlaceAmenities({
    this.delivery,
    this.dineIn,
    this.takeout,
    this.curbsidePickup,
    this.reservable,
    this.servesBreakfast,
    this.servesBrunch,
    this.servesLunch,
    this.servesDinner,
    this.servesVegetarianFood,
    this.servesDessert,
    this.servesCoffee,
    this.servesBeer,
    this.servesWine,
    this.servesCocktails,
    this.outdoorSeating,
    this.liveMusic,
    this.menuForChildren,
    this.goodForChildren,
    this.goodForGroups,
    this.goodForWatchingSports,
    this.allowsDogs,
    this.restroom,
  });

  /// Reads the amenity fields of a place.
  factory PlaceAmenities.fromJson(Map<String, Object?> json) => PlaceAmenities(
    delivery: json['delivery'] as bool?,
    dineIn: json['dineIn'] as bool?,
    takeout: json['takeout'] as bool?,
    curbsidePickup: json['curbsidePickup'] as bool?,
    reservable: json['reservable'] as bool?,
    servesBreakfast: json['servesBreakfast'] as bool?,
    servesBrunch: json['servesBrunch'] as bool?,
    servesLunch: json['servesLunch'] as bool?,
    servesDinner: json['servesDinner'] as bool?,
    servesVegetarianFood: json['servesVegetarianFood'] as bool?,
    servesDessert: json['servesDessert'] as bool?,
    servesCoffee: json['servesCoffee'] as bool?,
    servesBeer: json['servesBeer'] as bool?,
    servesWine: json['servesWine'] as bool?,
    servesCocktails: json['servesCocktails'] as bool?,
    outdoorSeating: json['outdoorSeating'] as bool?,
    liveMusic: json['liveMusic'] as bool?,
    menuForChildren: json['menuForChildren'] as bool?,
    goodForChildren: json['goodForChildren'] as bool?,
    goodForGroups: json['goodForGroups'] as bool?,
    goodForWatchingSports: json['goodForWatchingSports'] as bool?,
    allowsDogs: json['allowsDogs'] as bool?,
    restroom: json['restroom'] as bool?,
  );

  /// Delivers.
  final bool? delivery;

  /// Has seating to eat in.
  final bool? dineIn;

  /// Offers takeaway.
  final bool? takeout;

  /// Offers curbside pickup.
  final bool? curbsidePickup;

  /// Takes reservations.
  final bool? reservable;

  /// Serves breakfast.
  final bool? servesBreakfast;

  /// Serves brunch.
  final bool? servesBrunch;

  /// Serves lunch.
  final bool? servesLunch;

  /// Serves dinner.
  final bool? servesDinner;

  /// Serves vegetarian food.
  final bool? servesVegetarianFood;

  /// Serves dessert.
  final bool? servesDessert;

  /// Serves coffee.
  final bool? servesCoffee;

  /// Serves beer.
  final bool? servesBeer;

  /// Serves wine.
  final bool? servesWine;

  /// Serves cocktails.
  final bool? servesCocktails;

  /// Has outdoor seating.
  final bool? outdoorSeating;

  /// Has live music.
  final bool? liveMusic;

  /// Has a children's menu.
  final bool? menuForChildren;

  /// Good for children.
  final bool? goodForChildren;

  /// Good for groups.
  final bool? goodForGroups;

  /// Good for watching sports.
  final bool? goodForWatchingSports;

  /// Allows dogs.
  final bool? allowsDogs;

  /// Has a restroom.
  final bool? restroom;
}

/// Wheelchair access. Each value is null when Google doesn't know.
@immutable
class AccessibilityOptions {
  /// Creates accessibility options.
  const AccessibilityOptions({
    this.wheelchairAccessibleEntrance,
    this.wheelchairAccessibleParking,
    this.wheelchairAccessibleRestroom,
    this.wheelchairAccessibleSeating,
  });

  /// Reads `accessibilityOptions`.
  factory AccessibilityOptions.fromJson(
    Map<String, Object?> json,
  ) => AccessibilityOptions(
    wheelchairAccessibleEntrance: json['wheelchairAccessibleEntrance'] as bool?,
    wheelchairAccessibleParking: json['wheelchairAccessibleParking'] as bool?,
    wheelchairAccessibleRestroom: json['wheelchairAccessibleRestroom'] as bool?,
    wheelchairAccessibleSeating: json['wheelchairAccessibleSeating'] as bool?,
  );

  /// The entrance is wheelchair accessible.
  final bool? wheelchairAccessibleEntrance;

  /// Has wheelchair-accessible parking.
  final bool? wheelchairAccessibleParking;

  /// Has a wheelchair-accessible restroom.
  final bool? wheelchairAccessibleRestroom;

  /// Has wheelchair-accessible seating.
  final bool? wheelchairAccessibleSeating;
}

/// Parking. Each value is null when Google doesn't know.
@immutable
class ParkingOptions {
  /// Creates parking options.
  const ParkingOptions({
    this.freeParkingLot,
    this.paidParkingLot,
    this.freeStreetParking,
    this.paidStreetParking,
    this.freeGarageParking,
    this.paidGarageParking,
    this.valetParking,
  });

  /// Reads `parkingOptions`.
  factory ParkingOptions.fromJson(Map<String, Object?> json) => ParkingOptions(
    freeParkingLot: json['freeParkingLot'] as bool?,
    paidParkingLot: json['paidParkingLot'] as bool?,
    freeStreetParking: json['freeStreetParking'] as bool?,
    paidStreetParking: json['paidStreetParking'] as bool?,
    freeGarageParking: json['freeGarageParking'] as bool?,
    paidGarageParking: json['paidGarageParking'] as bool?,
    valetParking: json['valetParking'] as bool?,
  );

  /// Free parking lot.
  final bool? freeParkingLot;

  /// Paid parking lot.
  final bool? paidParkingLot;

  /// Free street parking.
  final bool? freeStreetParking;

  /// Paid street parking.
  final bool? paidStreetParking;

  /// Free garage parking.
  final bool? freeGarageParking;

  /// Paid garage parking.
  final bool? paidGarageParking;

  /// Valet parking.
  final bool? valetParking;
}

/// Accepted payment methods. Each value is null when Google doesn't know.
@immutable
class PaymentOptions {
  /// Creates payment options.
  const PaymentOptions({
    this.acceptsCreditCards,
    this.acceptsDebitCards,
    this.acceptsCashOnly,
    this.acceptsNfc,
  });

  /// Reads `paymentOptions`.
  factory PaymentOptions.fromJson(Map<String, Object?> json) => PaymentOptions(
    acceptsCreditCards: json['acceptsCreditCards'] as bool?,
    acceptsDebitCards: json['acceptsDebitCards'] as bool?,
    acceptsCashOnly: json['acceptsCashOnly'] as bool?,
    acceptsNfc: json['acceptsNfc'] as bool?,
  );

  /// Accepts credit cards.
  final bool? acceptsCreditCards;

  /// Accepts debit cards.
  final bool? acceptsDebitCards;

  /// Takes cash only.
  final bool? acceptsCashOnly;

  /// Accepts tap-to-pay (NFC), such as Google Pay.
  final bool? acceptsNfc;
}

/// Fuel prices at a petrol pump.
@immutable
class FuelOptions {
  /// Creates fuel options.
  const FuelOptions({this.prices = const []});

  /// Reads `fuelOptions`.
  factory FuelOptions.fromJson(Map<String, Object?> json) =>
      FuelOptions(prices: _objects(json['fuelPrices'], FuelPrice.fromJson));

  /// The price of each fuel.
  final List<FuelPrice> prices;
}

/// The price of one fuel.
@immutable
class FuelPrice {
  /// Creates a fuel price.
  const FuelPrice({required this.type, this.price, this.updateTime});

  /// Reads a fuel price.
  factory FuelPrice.fromJson(Map<String, Object?> json) => FuelPrice(
    type: (json['type'] ?? '') as String,
    price: _object(json['price'], Money.fromJson),
    updateTime: _time(json['updateTime']),
  );

  /// The fuel, such as `DIESEL`, `REGULAR_UNLEADED`, `PREMIUM` or `LPG`.
  final String type;

  /// The price per unit.
  final Money? price;

  /// When the price was last updated (UTC).
  final DateTime? updateTime;
}

/// Chargers at an EV charging station.
@immutable
class EvChargeOptions {
  /// Creates EV charging options.
  const EvChargeOptions({this.connectorCount, this.connectors = const []});

  /// Reads `evChargeOptions`.
  factory EvChargeOptions.fromJson(Map<String, Object?> json) =>
      EvChargeOptions(
        connectorCount: json['connectorCount'] as int?,
        connectors: _objects(
          json['connectorAggregation'],
          EvConnectorGroup.fromJson,
        ),
      );

  /// How many connectors there are in total.
  final int? connectorCount;

  /// The connectors, grouped by type and charge rate.
  final List<EvConnectorGroup> connectors;
}

/// Connectors of one type and charge rate.
@immutable
class EvConnectorGroup {
  /// Creates a connector group.
  const EvConnectorGroup({
    required this.type,
    this.maxChargeRateKw,
    this.count,
    this.availableCount,
    this.outOfServiceCount,
    this.availabilityUpdateTime,
  });

  /// Reads a connector group.
  factory EvConnectorGroup.fromJson(Map<String, Object?> json) =>
      EvConnectorGroup(
        type: (json['type'] ?? '') as String,
        maxChargeRateKw: _double(json['maxChargeRateKw']),
        count: json['count'] as int?,
        availableCount: json['availableCount'] as int?,
        outOfServiceCount: json['outOfServiceCount'] as int?,
        availabilityUpdateTime: _time(json['availabilityLastUpdateTime']),
      );

  /// The connector, such as `EV_CONNECTOR_TYPE_CCS_COMBO_2`.
  final String type;

  /// The maximum charge rate in kW.
  final double? maxChargeRateKw;

  /// How many of these connectors there are.
  final int? count;

  /// How many are free right now.
  final int? availableCount;

  /// How many are out of service.
  final int? outOfServiceCount;

  /// When the availability was last updated (UTC).
  final DateTime? availabilityUpdateTime;
}

/// Where a place is, described by nearby landmarks and areas.
@immutable
class AddressDescriptor {
  /// Creates an address descriptor.
  const AddressDescriptor({this.landmarks = const [], this.areas = const []});

  /// Reads `addressDescriptor`.
  factory AddressDescriptor.fromJson(Map<String, Object?> json) =>
      AddressDescriptor(
        landmarks: _objects(json['landmarks'], Landmark.fromJson),
        areas: _objects(json['areas'], AddressArea.fromJson),
      );

  /// Nearby landmarks, closest first.
  final List<Landmark> landmarks;

  /// Areas the place is in or near, such as a neighbourhood.
  final List<AddressArea> areas;
}

/// A landmark near a place, such as "across the road from Sassoon Dock".
@immutable
class Landmark {
  /// Creates a landmark.
  const Landmark({
    required this.placeId,
    required this.name,
    this.types = const [],
    this.spatialRelationship,
    this.straightLineDistanceMeters,
    this.travelDistanceMeters,
  });

  /// Reads a landmark.
  factory Landmark.fromJson(Map<String, Object?> json) => Landmark(
    placeId: (json['placeId'] ?? '') as String,
    name: _text(json['displayName']) ?? '',
    types: _strings(json['types']),
    spatialRelationship: json['spatialRelationship'] as String?,
    straightLineDistanceMeters: _double(json['straightLineDistanceMeters']),
    travelDistanceMeters: _double(json['travelDistanceMeters']),
  );

  /// The landmark's place ID.
  final String placeId;

  /// The landmark's name.
  final String name;

  /// The landmark's types.
  final List<String> types;

  /// How the place relates to it, such as `NEAR`, `WITHIN`, `BESIDE`,
  /// `ACROSS_THE_ROAD`, `DOWN_THE_ROAD`, `AROUND_THE_CORNER` or `BEHIND`.
  final String? spatialRelationship;

  /// The straight-line distance in meters.
  final double? straightLineDistanceMeters;

  /// The distance along roads in meters.
  final double? travelDistanceMeters;
}

/// An area a place is in or near.
@immutable
class AddressArea {
  /// Creates an area.
  const AddressArea({
    required this.placeId,
    required this.name,
    this.containment,
  });

  /// Reads an area.
  factory AddressArea.fromJson(Map<String, Object?> json) => AddressArea(
    placeId: (json['placeId'] ?? '') as String,
    name: _text(json['displayName']) ?? '',
    containment: json['containment'] as String?,
  );

  /// The area's place ID.
  final String placeId;

  /// The area's name.
  final String name;

  /// How the place relates to it: `WITHIN`, `OUTSKIRTS` or `NEAR`.
  final String? containment;
}

/// A point to stop at when going to a place, such as an entrance.
@immutable
class NavigationPoint {
  /// Creates a navigation point.
  const NavigationPoint({
    this.name,
    this.location,
    this.travelModes = const [],
  });

  /// Reads a navigation point.
  factory NavigationPoint.fromJson(Map<String, Object?> json) =>
      NavigationPoint(
        name: _text(json['displayName']),
        location: _object(json['location'], Coordinates.fromJson),
        travelModes: _strings(json['travelModes']),
      );

  /// A description, such as the road name.
  final String? name;

  /// Where it is.
  final Coordinates? location;

  /// Who it is for: `DRIVE`, `WALK`.
  final List<String> travelModes;
}

/// The places from [GooglePlaces.searchText], with a token for the next
/// page. It is a normal list of [Place]s.
class PlaceSearchResults extends UnmodifiableListView<Place> {
  /// Creates search results.
  PlaceSearchResults(super.places, {this.nextPageToken});

  /// Pass it as `pageToken` to [GooglePlaces.searchText], with the same
  /// query and filters, for more results. Null on the last page.
  final String? nextPageToken;
}

// Geocoding ------------------------------------------------------------------

/// One result from [GooglePlaces.reverseGeocode] or [GooglePlaces.geocode].
@immutable
class GeocodingResult {
  /// Creates a geocoding result.
  const GeocodingResult({
    required this.placeId,
    required this.formattedAddress,
    required this.location,
    this.types = const [],
    this.addressComponents = const [],
    this.locationType,
    this.viewport,
    this.bounds,
    this.plusCode,
    this.postcodeLocalities = const [],
    this.partialMatch = false,
  });

  /// Reads a result from the Geocoding API.
  factory GeocodingResult.fromJson(Map<String, Object?> json) {
    final geometry = _map(json['geometry']);
    return GeocodingResult(
      placeId: (json['place_id'] ?? '') as String,
      formattedAddress: (json['formatted_address'] ?? '') as String,
      location: Coordinates.fromJson(_map(geometry['location'])),
      types: _strings(json['types']),
      addressComponents: _objects(
        json['address_components'],
        AddressComponent.fromJson,
      ),
      locationType: _locationTypes[geometry['location_type']],
      viewport: _object(geometry['viewport'], Viewport.fromJson),
      bounds: _object(geometry['bounds'], Viewport.fromJson),
      plusCode: _object(json['plus_code'], PlusCode.fromJson),
      postcodeLocalities: _strings(json['postcode_localities']),
      partialMatch: (json['partial_match'] ?? false) as bool,
    );
  }

  /// The place ID. It works with [GooglePlaces.details] too.
  final String placeId;

  /// The full address.
  final String formattedAddress;

  /// Where it is.
  final Coordinates location;

  /// What it is, such as `street_address` or `locality`.
  final List<String> types;

  /// The address split into parts. Use [AddressParts] for the city, state,
  /// postal code and country.
  final List<AddressComponent> addressComponents;

  /// How exact [location] is.
  final LocationType? locationType;

  /// The area to show on a map.
  final Viewport? viewport;

  /// The whole area of the result, for areas such as a city.
  final Viewport? bounds;

  /// The plus code.
  final PlusCode? plusCode;

  /// The localities a postal code covers, when it covers several.
  final List<String> postcodeLocalities;

  /// True when Google matched only part of the address you gave.
  final bool partialMatch;

  @override
  String toString() => 'GeocodingResult($formattedAddress)';
}

/// How exact a [GeocodingResult.location] is.
enum LocationType {
  /// An exact street address.
  rooftop,

  /// Between two exact points, such as along a street.
  rangeInterpolated,

  /// The middle of a street or an area.
  geometricCenter,

  /// An estimate.
  approximate,
}

// Parsing helpers ------------------------------------------------------------

const _priceLevels = {
  'PRICE_LEVEL_FREE': PriceLevel.free,
  'PRICE_LEVEL_INEXPENSIVE': PriceLevel.inexpensive,
  'PRICE_LEVEL_MODERATE': PriceLevel.moderate,
  'PRICE_LEVEL_EXPENSIVE': PriceLevel.expensive,
  'PRICE_LEVEL_VERY_EXPENSIVE': PriceLevel.veryExpensive,
};

const _businessStatuses = {
  'OPERATIONAL': BusinessStatus.operational,
  'CLOSED_TEMPORARILY': BusinessStatus.closedTemporarily,
  'CLOSED_PERMANENTLY': BusinessStatus.closedPermanently,
};

const _locationTypes = {
  'ROOFTOP': LocationType.rooftop,
  'RANGE_INTERPOLATED': LocationType.rangeInterpolated,
  'GEOMETRIC_CENTER': LocationType.geometricCenter,
  'APPROXIMATE': LocationType.approximate,
};

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _strings(Object? value) => [
  for (final item in _list(value))
    if (item is String) item,
];

double? _double(Object? value) => (value as num?)?.toDouble();

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

T? _object<T>(Object? value, T Function(Map<String, Object?>) fromJson) =>
    value is Map ? fromJson(value.cast()) : null;

List<T> _objects<T>(Object? value, T Function(Map<String, Object?>) fromJson) =>
    [for (final item in _list(value)) fromJson(_map(item))];

/// Reads `{"text": ...}` objects such as `displayName`.
String? _text(Object? value) =>
    value is Map ? value['text'] as String? : value as String?;

List<TextMatch> _matches(Object? value) =>
    _objects(_map(value)['matches'], TextMatch.fromJson);
