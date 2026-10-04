import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models.dart';
import 'place_field.dart';

/// Groups the autocomplete requests a user makes while typing with the
/// [GooglePlaces.details] call for the place they pick.
///
/// Google then bills the typing as one session instead of per keystroke.
/// Use one session per search: create it when the user starts typing, pass
/// it to every [GooglePlaces.autocomplete] call and to the final
/// [GooglePlaces.details] call, then make a new one. The widgets in this
/// package do this for you.
class PlacesSession {
  /// Starts a new session with a random token.
  PlacesSession() : token = _uuidV4();

  /// The session token sent to Google (a version 4 UUID).
  final String token;

  static String _uuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// Google Places API (New) and Geocoding API.
///
/// ```dart
/// final places = GooglePlaces(apiKey: 'your-api-key');
///
/// final suggestions = await places.autocomplete('Gateway of In');
/// final place = await places.details(suggestions.first.placeId);
/// final address = await places.reverseGeocode(Coordinates(18.922, 72.834));
/// ```
///
/// Works on Android, iOS, web and desktop. Every method throws a
/// [PlacesException] when Google refuses the request or can't be reached.
class GooglePlaces {
  /// Creates a client.
  ///
  /// [languageCode] (such as `'hi'`) and [regionCode] (such as `'IN'`) are
  /// the defaults for every request; each method can override them.
  ///
  /// If the key has Android app or iOS app restrictions, pass
  /// [androidPackageName] with [androidCertFingerprint] (the SHA-1 of the
  /// signing certificate), or [iosBundleId], so Google can match the key's
  /// restrictions.
  GooglePlaces({
    required this.apiKey,
    this.languageCode,
    this.regionCode,
    this.androidPackageName,
    this.androidCertFingerprint,
    this.iosBundleId,
    this.timeout = const Duration(seconds: 15),
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// The Google Maps Platform API key.
  final String apiKey;

  /// The default language of names and addresses, such as `'en'` or `'hi'`.
  final String? languageCode;

  /// The default region (two-letter country code), such as `'IN'`. It
  /// affects formatting and ranking, not which places are found.
  final String? regionCode;

  /// The app's package name, for keys restricted to an Android app.
  final String? androidPackageName;

  /// The SHA-1 fingerprint of the app's signing certificate, for keys
  /// restricted to an Android app. With or without colons.
  final String? androidCertFingerprint;

  /// The app's bundle ID, for keys restricted to an iOS app.
  final String? iosBundleId;

  /// How long to wait for Google before throwing
  /// [PlacesErrorCode.network].
  final Duration timeout;

  final http.Client _client;
  final bool _ownsClient;

  static GooglePlaces? _instance;

  /// Creates the app-wide client returned by [instance]. Call it once, such
  /// as in `main()` before `runApp`, then use [GooglePlaces.instance]
  /// anywhere. The widgets and `PlaceAutocompleteController` use it when you
  /// don't pass a client.
  ///
  /// ```dart
  /// void main() {
  ///   GooglePlaces.initialize(apiKey: const String.fromEnvironment('PLACES_API_KEY'));
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Calling it again replaces the instance, for example when the user
  /// changes the app's language. Requests already running finish on the
  /// old client. Returns the new instance.
  static GooglePlaces initialize({
    required String apiKey,
    String? languageCode,
    String? regionCode,
    String? androidPackageName,
    String? androidCertFingerprint,
    String? iosBundleId,
    Duration timeout = const Duration(seconds: 15),
    http.Client? httpClient,
  }) => _instance = GooglePlaces(
    apiKey: apiKey,
    languageCode: languageCode,
    regionCode: regionCode,
    androidPackageName: androidPackageName,
    androidCertFingerprint: androidCertFingerprint,
    iosBundleId: iosBundleId,
    timeout: timeout,
    httpClient: httpClient,
  );

  /// The app-wide client created by [initialize].
  ///
  /// Throws a [StateError] that says what to do if [initialize] wasn't
  /// called.
  static GooglePlaces get instance =>
      _instance ??
      (throw StateError(
        'GooglePlaces.initialize(apiKey: ...) was not called. Call it once '
        'in main() before runApp(), or pass a GooglePlaces client to the '
        'widget or controller.',
      ));

  /// Whether [initialize] was called.
  static bool get isInitialized => _instance != null;

  static const _places = 'https://places.googleapis.com/v1';
  static const _geocode = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// Suggestions for what the user is typing, such as a search box that
  /// suggests "Gateway Of India" for "gateway of in".
  ///
  /// Pass a [session] to group the requests of one search; see
  /// [PlacesSession]. An empty [input] returns no suggestions without a
  /// request.
  ///
  /// * [locationBias] prefers places in an area; [locationRestriction]
  ///   returns only places in it. Use one or the other.
  /// * [types] limits the results to up to five place types, such as
  ///   `['restaurant']`, or `['(cities)']` and `['(regions)']`.
  /// * [countries] limits them to up to 15 countries, such as `['IN']`.
  /// * With [origin], each suggestion has its
  ///   [PlaceSuggestion.distanceMeters].
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    PlacesSession? session,
    LocationArea? locationBias,
    LocationArea? locationRestriction,
    List<String> types = const [],
    List<String> countries = const [],
    Coordinates? origin,
    String? languageCode,
    String? regionCode,
  }) async {
    if (input.trim().isEmpty) return const [];
    final json = await _post('places:autocomplete', {
      'input': input,
      'sessionToken': ?session?.token,
      'locationBias': ?locationBias?.toJson(),
      'locationRestriction': ?locationRestriction?.toJson(),
      if (types.isNotEmpty) 'includedPrimaryTypes': types,
      if (countries.isNotEmpty) 'includedRegionCodes': countries,
      'origin': ?origin?.toJson(),
      'languageCode': ?(languageCode ?? this.languageCode),
      'regionCode': ?(regionCode ?? this.regionCode),
    });
    return [
      for (final suggestion in _list(json['suggestions']))
        if (_map(suggestion)['placePrediction'] case final Map prediction)
          PlaceSuggestion.fromJson(prediction.cast()),
    ];
  }

  /// The place with [placeId], with the [fields] you ask for.
  ///
  /// Ask only for the fields you show: Google bills by the most expensive
  /// one (see [PlaceField]). Pass the [session] used for
  /// [autocomplete] to end it; start a new one afterwards.
  Future<Place> details(
    String placeId, {
    List<PlaceField> fields = PlaceField.basic,
    PlacesSession? session,
    String? languageCode,
    String? regionCode,
  }) async {
    final language = languageCode ?? this.languageCode;
    final region = regionCode ?? this.regionCode;
    final uri = Uri.parse('$_places/places/$placeId').replace(
      queryParameters: {
        'languageCode': ?language,
        'regionCode': ?region,
        'sessionToken': ?session?.token,
      },
    );
    final json = await _send('GET', uri, fieldMask: _mask(fields));
    return Place.fromJson(json);
  }

  /// Places that match a text query, such as "pizza in New York" or
  /// "petrol pump near Andheri".
  ///
  /// * [locationBias] prefers places in an area (circle or rectangle);
  ///   [locationRestriction] returns only places in it (rectangle only).
  /// * [includedType] limits results to one type, such as `'restaurant'`.
  /// * [openNow] returns only places open right now.
  /// * [minRating] returns only places rated at least this (0 to 5).
  /// * [maxResults] is 1 to 20 per page.
  ///
  /// Returns up to 20 places. For more (up to 60), call it again with the
  /// same arguments and `pageToken: results.nextPageToken`.
  Future<PlaceSearchResults> searchText(
    String query, {
    List<PlaceField> fields = PlaceField.basic,
    LocationArea? locationBias,
    LocationArea? locationRestriction,
    String? includedType,
    bool openNow = false,
    double? minRating,
    int? maxResults,
    String? pageToken,
    String? languageCode,
    String? regionCode,
  }) async {
    final json = await _post('places:searchText', {
      'textQuery': query,
      'locationBias': ?locationBias?.toJson(),
      'locationRestriction': ?locationRestriction?.toJson(),
      'includedType': ?includedType,
      if (openNow) 'openNow': true,
      'minRating': ?minRating,
      'pageSize': ?maxResults,
      'pageToken': ?pageToken,
      'languageCode': ?(languageCode ?? this.languageCode),
      'regionCode': ?(regionCode ?? this.regionCode),
    }, fieldMask: '${_mask(fields, prefix: 'places.')},nextPageToken');
    return PlaceSearchResults(
      _placesOf(json),
      nextPageToken: json['nextPageToken'] as String?,
    );
  }

  /// Places in an [area] (a [LocationArea.circle]), such as cafés within
  /// a kilometer.
  ///
  /// * [includedTypes] and [excludedTypes] filter by type, such as
  ///   `['cafe']`.
  /// * [maxResults] is 1 to 20.
  /// * With [rankByDistance], the nearest places come first; otherwise the
  ///   most popular.
  Future<List<Place>> searchNearby(
    LocationArea area, {
    List<PlaceField> fields = PlaceField.basic,
    List<String> includedTypes = const [],
    List<String> excludedTypes = const [],
    int? maxResults,
    bool rankByDistance = false,
    String? languageCode,
    String? regionCode,
  }) async {
    final json = await _post('places:searchNearby', {
      'locationRestriction': area.toJson(),
      if (includedTypes.isNotEmpty) 'includedTypes': includedTypes,
      if (excludedTypes.isNotEmpty) 'excludedTypes': excludedTypes,
      'maxResultCount': ?maxResults,
      if (rankByDistance) 'rankPreference': 'DISTANCE',
      'languageCode': ?(languageCode ?? this.languageCode),
      'regionCode': ?(regionCode ?? this.regionCode),
    }, fieldMask: _mask(fields, prefix: 'places.'));
    return _placesOf(json);
  }

  /// An image URL for [photo], to show with `Image.network`.
  ///
  /// The URL doesn't contain your API key, so it's safe to cache or pass
  /// around. Give [maxWidth] and/or [maxHeight] (1 to 4800 pixels); the
  /// photo is scaled down to fit, keeping its shape.
  ///
  /// Google requires you to show the photo's
  /// [PlacePhoto.authorAttributions] with it.
  Future<String> photoUrl(
    PlacePhoto photo, {
    int? maxWidth = 800,
    int? maxHeight,
  }) async {
    final uri = Uri.parse('$_places/${photo.name}/media').replace(
      queryParameters: {
        'maxWidthPx': ?maxWidth?.toString(),
        'maxHeightPx': ?maxHeight?.toString(),
        'skipHttpRedirect': 'true',
      },
    );
    final json = await _send('GET', uri);
    return json['photoUri'] as String;
  }

  /// The addresses at [location], most precise first: usually a street
  /// address, then the area, city, state and country.
  ///
  /// Returns an empty list when Google has no address there, such as in the
  /// middle of the sea. [resultTypes] limits the results, such as
  /// `['street_address']` or `['locality']`.
  ///
  /// Uses the Geocoding API.
  Future<List<GeocodingResult>> reverseGeocode(
    Coordinates location, {
    List<String> resultTypes = const [],
    String? languageCode,
    String? regionCode,
  }) => _geocodeRequest({
    'latlng': '${location.latitude},${location.longitude}',
    if (resultTypes.isNotEmpty) 'result_type': resultTypes.join('|'),
    'language': ?(languageCode ?? this.languageCode),
    'region': ?(regionCode ?? this.regionCode)?.toLowerCase(),
  });

  /// The places matching an [address], best match first, each with its
  /// [GeocodingResult.location].
  ///
  /// Returns an empty list when nothing matches. [countries] limits the
  /// results to those countries, such as `['IN']`.
  ///
  /// Uses the Geocoding API.
  Future<List<GeocodingResult>> geocode(
    String address, {
    List<String> countries = const [],
    String? languageCode,
    String? regionCode,
  }) => _geocodeRequest({
    'address': address,
    if (countries.isNotEmpty)
      'components': [for (final c in countries) 'country:$c'].join('|'),
    'language': ?(languageCode ?? this.languageCode),
    'region': ?(regionCode ?? this.regionCode)?.toLowerCase(),
  });

  /// Closes the HTTP client, if this object created it. Don't close
  /// [instance] while the app still uses it.
  void close() {
    if (_ownsClient) _client.close();
    if (identical(_instance, this)) _instance = null;
  }

  Future<List<GeocodingResult>> _geocodeRequest(
    Map<String, String> query,
  ) async {
    final uri = Uri.parse(
      _geocode,
    ).replace(queryParameters: {...query, 'key': apiKey});
    final json = await _send('GET', uri, geocoding: true);
    final status = json['status'] as String?;
    if (status == 'ZERO_RESULTS') return const [];
    if (status != 'OK') {
      throw _geocodingError(status, json['error_message'] as String?);
    }
    return [
      for (final result in _list(json['results']))
        GeocodingResult.fromJson(_map(result)),
    ];
  }

  Future<Map<String, Object?>> _post(
    String method,
    Map<String, Object?> body, {
    String? fieldMask,
  }) => _send(
    'POST',
    Uri.parse('$_places/$method'),
    body: body,
    fieldMask: fieldMask,
  );

  Future<Map<String, Object?>> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    String? fieldMask,
    bool geocoding = false,
  }) async {
    final request = http.Request(method, uri);
    if (!geocoding) request.headers['X-Goog-Api-Key'] = apiKey;
    if (fieldMask != null) request.headers['X-Goog-FieldMask'] = fieldMask;
    if (androidPackageName != null) {
      request.headers['X-Android-Package'] = androidPackageName!;
    }
    if (androidCertFingerprint != null) {
      request.headers['X-Android-Cert'] = androidCertFingerprint!
          .replaceAll(':', '')
          .toUpperCase();
    }
    if (iosBundleId != null) {
      request.headers['X-Ios-Bundle-Identifier'] = iosBundleId!;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const PlacesException(PlacesErrorCode.network);
    } catch (e) {
      throw PlacesException(
        PlacesErrorCode.network,
        serverMessage: _hideKey(e.toString()),
      );
    }

    Map<String, Object?> json;
    try {
      json = _map(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      json = const {};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    throw _placesError(response.statusCode, _map(json['error']));
  }

  PlacesException _placesError(int statusCode, Map<String, Object?> error) {
    final status = error['status'] as String?;
    String? reason;
    for (final detail in _list(error['details'])) {
      final info = _map(detail);
      if (info['reason'] case final String r) reason = r;
    }
    final message = error['message'] as String?;
    final code = switch (reason) {
      'API_KEY_INVALID' => PlacesErrorCode.invalidApiKey,
      'SERVICE_DISABLED' => PlacesErrorCode.apiNotEnabled,
      'BILLING_DISABLED' => PlacesErrorCode.billingNotEnabled,
      'RATE_LIMIT_EXCEEDED' => PlacesErrorCode.quotaExceeded,
      final String r when r.startsWith('API_KEY_') && r.endsWith('_BLOCKED') =>
        PlacesErrorCode.keyRestricted,
      _ => switch (status) {
        'RESOURCE_EXHAUSTED' => PlacesErrorCode.quotaExceeded,
        'INVALID_ARGUMENT' => PlacesErrorCode.invalidRequest,
        'NOT_FOUND' => PlacesErrorCode.notFound,
        'PERMISSION_DENIED' => PlacesErrorCode.permissionDenied,
        _ when statusCode == 429 => PlacesErrorCode.quotaExceeded,
        _ when statusCode >= 500 => PlacesErrorCode.server,
        _ => PlacesErrorCode.unknown,
      },
    };
    return PlacesException(
      code,
      serverMessage: message,
      statusCode: statusCode,
      reason: reason ?? status,
    );
  }

  PlacesException _geocodingError(String? status, String? message) {
    final text = (message ?? '').toLowerCase();
    final code = switch (status) {
      'OVER_QUERY_LIMIT' => PlacesErrorCode.quotaExceeded,
      'INVALID_REQUEST' => PlacesErrorCode.invalidRequest,
      'UNKNOWN_ERROR' => PlacesErrorCode.server,
      _ when text.contains('not activated') || text.contains('not enabled') =>
        PlacesErrorCode.apiNotEnabled,
      _ when text.contains('billing') => PlacesErrorCode.billingNotEnabled,
      _ when text.contains('key is invalid') => PlacesErrorCode.invalidApiKey,
      _ when text.contains('not authorized') || text.contains('restriction') =>
        PlacesErrorCode.keyRestricted,
      'OVER_DAILY_LIMIT' => PlacesErrorCode.quotaExceeded,
      'REQUEST_DENIED' => PlacesErrorCode.permissionDenied,
      _ => PlacesErrorCode.unknown,
    };
    return PlacesException(code, serverMessage: message, reason: status);
  }

  String _hideKey(String text) => text.replaceAll(apiKey, '<API key>');

  static String _mask(List<PlaceField> fields, {String prefix = ''}) =>
      {for (final field in fields) '$prefix${field.value}'}.join(',');

  static List<Place> _placesOf(Map<String, Object?> json) => [
    for (final place in _list(json['places'])) Place.fromJson(_map(place)),
  ];
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

List<Object?> _list(Object? value) => value is List ? value : const [];
