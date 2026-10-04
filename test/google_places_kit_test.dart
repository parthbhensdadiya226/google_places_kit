import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_kit/google_places_kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  /// A client whose requests are answered by [handler] with JSON.
  GooglePlaces client(
    Object? Function(http.Request request) handler, {
    int status = 200,
    String? languageCode,
    String? androidPackageName,
    String? androidCertFingerprint,
    String? iosBundleId,
  }) {
    requests = [];
    return GooglePlaces(
      apiKey: 'test-key',
      languageCode: languageCode,
      androidPackageName: androidPackageName,
      androidCertFingerprint: androidCertFingerprint,
      iosBundleId: iosBundleId,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(handler(request)),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  Map<String, Object?> body(http.Request request) =>
      jsonDecode(request.body) as Map<String, Object?>;

  const gateway = {
    'id': 'ChIJgateway',
    'displayName': {'text': 'Gateway Of India Mumbai', 'languageCode': 'en'},
    'formattedAddress': 'Apollo Bandar, Colaba, Mumbai, Maharashtra, India',
    'location': {'latitude': 18.9219841, 'longitude': 72.8346543},
    'types': ['tourist_attraction', 'point_of_interest'],
    'addressComponents': [
      {
        'longText': 'Colaba',
        'shortText': 'Colaba',
        'types': ['sublocality'],
      },
      {
        'longText': 'Mumbai',
        'shortText': 'Mumbai',
        'types': ['locality'],
      },
      {
        'longText': 'Maharashtra',
        'shortText': 'MH',
        'types': ['administrative_area_level_1'],
      },
      {
        'longText': 'India',
        'shortText': 'IN',
        'types': ['country'],
      },
      {
        'longText': '400001',
        'shortText': '400001',
        'types': ['postal_code'],
      },
    ],
    'rating': 4.6,
    'userRatingCount': 120000,
    'priceLevel': 'PRICE_LEVEL_FREE',
    'businessStatus': 'OPERATIONAL',
    'currentOpeningHours': {
      'openNow': true,
      'weekdayDescriptions': ['Monday: Open 24 hours'],
    },
    'photos': [
      {
        'name': 'places/ChIJgateway/photos/abc',
        'widthPx': 4000,
        'heightPx': 3000,
        'authorAttributions': [
          {'displayName': 'A Photographer', 'uri': 'https://maps.google.com/x'},
        ],
      },
    ],
  };

  group('autocomplete', () {
    test('sends the input and filters, and reads the suggestions', () async {
      final places = client(
        (_) => {
          'suggestions': [
            {
              'placePrediction': {
                'placeId': 'ChIJgateway',
                'text': {'text': 'Gateway Of India, Colaba, Mumbai, India'},
                'structuredFormat': {
                  'mainText': {
                    'text': 'Gateway Of India',
                    'matches': [
                      {'endOffset': 10},
                    ],
                  },
                  'secondaryText': {'text': 'Colaba, Mumbai, India'},
                },
                'types': ['tourist_attraction'],
                'distanceMeters': 1520,
              },
            },
            {
              'queryPrediction': {
                'text': {'text': 'gateway of india ferry'},
              },
            },
          ],
        },
        languageCode: 'en',
      );
      final session = PlacesSession();
      final suggestions = await places.autocomplete(
        'gateway of in',
        session: session,
        locationBias: const LocationArea.circle(Coordinates(19, 72.8), 5000),
        types: ['tourist_attraction'],
        countries: ['IN'],
        origin: const Coordinates(19, 72.8),
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://places.googleapis.com/v1/places:autocomplete',
      );
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      expect(body(request), {
        'input': 'gateway of in',
        'sessionToken': session.token,
        'locationBias': {
          'circle': {
            'center': {'latitude': 19.0, 'longitude': 72.8},
            'radius': 5000.0,
          },
        },
        'includedPrimaryTypes': ['tourist_attraction'],
        'includedRegionCodes': ['IN'],
        'origin': {'latitude': 19.0, 'longitude': 72.8},
        'languageCode': 'en',
      });

      final suggestion = suggestions.single;
      expect(suggestion.placeId, 'ChIJgateway');
      expect(suggestion.mainText, 'Gateway Of India');
      expect(suggestion.secondaryText, 'Colaba, Mumbai, India');
      expect(suggestion.distanceMeters, 1520);
      expect(suggestion.mainTextMatches.single.start, 0);
      expect(suggestion.mainTextMatches.single.end, 10);
    });

    test('an empty input makes no request', () async {
      final places = client((_) => fail('no request expected'));
      expect(await places.autocomplete('  '), isEmpty);
      expect(requests, isEmpty);
    });
  });

  test('details asks only for the given fields and reads them', () async {
    final places = client((_) => gateway);
    final session = PlacesSession();
    final place = await places.details(
      'ChIJgateway',
      fields: [PlaceField.displayName, PlaceField.location],
      session: session,
      languageCode: 'hi',
    );

    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/v1/places/ChIJgateway');
    expect(request.url.queryParameters, {
      'languageCode': 'hi',
      'sessionToken': session.token,
    });
    expect(request.headers['X-Goog-FieldMask'], 'displayName,location');

    expect(place.id, 'ChIJgateway');
    expect(place.name, 'Gateway Of India Mumbai');
    expect(place.location, const Coordinates(18.9219841, 72.8346543));
    expect(place.rating, 4.6);
    expect(place.userRatingCount, 120000);
    expect(place.priceLevel, PriceLevel.free);
    expect(place.businessStatus, BusinessStatus.operational);
    expect(place.openNow, isTrue);
    expect(
      place.photos.single.authorAttributions.single.displayName,
      'A Photographer',
    );
    expect(place.json['id'], 'ChIJgateway');
  });

  test('address parts are easy to read', () {
    final address = Place.fromJson(gateway).addressComponents;
    expect(address.area, 'Colaba');
    expect(address.city, 'Mumbai');
    expect(address.state, 'Maharashtra');
    expect(address.stateCode, 'MH');
    expect(address.postalCode, '400001');
    expect(address.country, 'India');
    expect(address.countryCode, 'IN');
    expect(address.street, isNull);
  });

  test('searchText prefixes the field mask and sends the filters', () async {
    final places = client(
      (_) => {
        'places': [gateway],
      },
    );
    final results = await places.searchText(
      'monuments in Mumbai',
      fields: PlaceField.basic,
      openNow: true,
      minRating: 4,
      maxResults: 5,
    );
    final request = requests.single;
    expect(request.url.path, '/v1/places:searchText');
    expect(
      request.headers['X-Goog-FieldMask'],
      'places.id,places.displayName,places.formattedAddress,'
      'places.location,places.types,nextPageToken',
    );
    expect(body(request), {
      'textQuery': 'monuments in Mumbai',
      'openNow': true,
      'minRating': 4.0,
      'pageSize': 5,
    });
    expect(results.single.name, 'Gateway Of India Mumbai');
    expect(results.nextPageToken, isNull);
  });

  test('searchText pages with nextPageToken', () async {
    final places = client(
      (request) => body(request)['pageToken'] == null
          ? {
              'places': [gateway],
              'nextPageToken': 'page-2',
            }
          : {
              'places': [gateway],
            },
    );
    final first = await places.searchText('monuments');
    expect(first.nextPageToken, 'page-2');
    final second = await places.searchText(
      'monuments',
      pageToken: first.nextPageToken,
    );
    expect(body(requests.last)['pageToken'], 'page-2');
    expect(second.nextPageToken, isNull);
    expect(second, hasLength(1));
  });

  test('every nested field is read into a model', () {
    final place = Place.fromJson({
      'id': 'p1',
      'displayName': {'text': 'Pizza Place'},
      'googleMapsTypeLabel': {'text': 'Pizza Restaurant'},
      'timeZone': {'id': 'Asia/Calcutta'},
      'viewport': {
        'low': {'latitude': 1, 'longitude': 2},
        'high': {'latitude': 3, 'longitude': 4},
      },
      'plusCode': {
        'globalCode': '7JCJWR7F+VP',
        'compoundCode': 'WR7F+VP Mumbai',
      },
      'postalAddress': {
        'regionCode': 'IN',
        'postalCode': '400005',
        'locality': 'Mumbai',
        'addressLines': ['Ground Floor', 'Main Rd'],
      },
      'regularOpeningHours': {
        'openNow': false,
        'periods': [
          {
            'open': {'day': 1, 'hour': 11, 'minute': 30},
            'close': {'day': 1, 'hour': 23, 'minute': 0},
          },
          {
            'open': {
              'day': 0,
              'hour': 0,
              'minute': 0,
              'date': {'year': 2026, 'month': 10, 'day': 4},
            },
          },
        ],
        'nextOpenTime': '2026-10-05T06:00:00Z',
      },
      'regularSecondaryOpeningHours': [
        {'secondaryHoursType': 'DELIVERY', 'openNow': true},
      ],
      'priceRange': {
        'startPrice': {'currencyCode': 'INR', 'units': '200'},
        'endPrice': {'currencyCode': 'INR', 'units': '400', 'nanos': 500000000},
      },
      'delivery': true,
      'servesVegetarianFood': true,
      'allowsDogs': false,
      'parkingOptions': {'freeStreetParking': true},
      'paymentOptions': {'acceptsNfc': true, 'acceptsCashOnly': false},
      'accessibilityOptions': {'wheelchairAccessibleEntrance': true},
      'fuelOptions': {
        'fuelPrices': [
          {
            'type': 'DIESEL',
            'price': {'currencyCode': 'INR', 'units': '90', 'nanos': 30000000},
            'updateTime': '2026-10-01T10:00:00Z',
          },
        ],
      },
      'evChargeOptions': {
        'connectorCount': 4,
        'connectorAggregation': [
          {
            'type': 'EV_CONNECTOR_TYPE_CCS_COMBO_2',
            'maxChargeRateKw': 60,
            'count': 2,
            'availableCount': 1,
          },
        ],
      },
      'addressDescriptor': {
        'landmarks': [
          {
            'placeId': 'l1',
            'displayName': {'text': 'Sassoon Dock'},
            'spatialRelationship': 'ACROSS_THE_ROAD',
            'straightLineDistanceMeters': 21.6,
          },
        ],
        'areas': [
          {
            'placeId': 'a1',
            'displayName': {'text': 'Colaba'},
            'containment': 'WITHIN',
          },
        ],
      },
      'generativeSummary': {
        'overview': {'text': 'A pizza place.'},
        'disclosureText': {'text': 'Summarized with Gemini'},
      },
      'reviewSummary': {
        'text': {'text': 'People like the pizza.'},
        'reviewsUri': 'https://maps.google.com/reviews',
      },
      'reviews': [
        {
          'rating': 4,
          'text': {'text': 'Good', 'languageCode': 'en'},
          'originalText': {'text': 'Good'},
          'authorAttribution': {'displayName': 'Asha'},
          'publishTime': '2026-05-14T06:56:28Z',
          'relativePublishTimeDescription': '4 months ago',
        },
      ],
      'googleMapsLinks': {'directionsUri': 'https://maps.google.com/dir'},
      'navigationPoints': [
        {
          'displayName': {'text': 'Main Rd'},
          'location': {'latitude': 1, 'longitude': 2},
          'travelModes': ['DRIVE', 'WALK'],
        },
      ],
      'containingPlaces': [
        {'name': 'places/m1', 'id': 'm1'},
      ],
    });

    expect(place.googleMapsTypeLabel, 'Pizza Restaurant');
    expect(place.timeZone, 'Asia/Calcutta');
    expect(place.viewport!.center, const Coordinates(2, 3));
    expect(place.plusCode!.globalCode, '7JCJWR7F+VP');
    expect(place.postalAddress!.addressLines, ['Ground Floor', 'Main Rd']);

    final hours = place.openingHours!;
    expect(place.openNow, isFalse);
    expect(hours.nextOpenTime, DateTime.utc(2026, 10, 5, 6));
    expect(hours.periods.first.open.day, 1);
    expect(hours.periods.first.open.hour, 11);
    expect(hours.periods.first.close!.hour, 23);
    expect(hours.periods.last.close, isNull); // open 24 hours
    expect(hours.periods.last.open.date, DateTime(2026, 10, 4));
    expect(place.secondaryOpeningHours.single.type, 'DELIVERY');

    expect(place.priceRange!.start!.amount, 200);
    expect(place.priceRange!.end!.amount, 400.5);
    expect(place.amenities.delivery, isTrue);
    expect(place.amenities.servesVegetarianFood, isTrue);
    expect(place.amenities.allowsDogs, isFalse);
    expect(place.amenities.liveMusic, isNull);
    expect(place.parking!.freeStreetParking, isTrue);
    expect(place.payment!.acceptsNfc, isTrue);
    expect(place.accessibility!.wheelchairAccessibleEntrance, isTrue);

    final diesel = place.fuelOptions!.prices.single;
    expect(diesel.type, 'DIESEL');
    expect(diesel.price!.amount, closeTo(90.03, 0.0001));
    expect(diesel.updateTime, DateTime.utc(2026, 10, 1, 10));
    final ev = place.evChargeOptions!;
    expect(ev.connectorCount, 4);
    expect(ev.connectors.single.maxChargeRateKw, 60);
    expect(ev.connectors.single.availableCount, 1);

    final landmark = place.addressDescriptor!.landmarks.single;
    expect(landmark.name, 'Sassoon Dock');
    expect(landmark.spatialRelationship, 'ACROSS_THE_ROAD');
    expect(place.addressDescriptor!.areas.single.containment, 'WITHIN');

    expect(place.generativeSummary!.text, 'A pizza place.');
    expect(place.generativeSummary!.disclosureText, 'Summarized with Gemini');
    expect(place.reviewSummary!.text, 'People like the pizza.');
    final review = place.reviews.single;
    expect(review.author.displayName, 'Asha');
    expect(review.rating, 4);
    expect(review.languageCode, 'en');
    expect(review.publishTime, DateTime.utc(2026, 5, 14, 6, 56, 28));

    expect(place.googleMapsLinks!.directionsUri, 'https://maps.google.com/dir');
    expect(place.navigationPoints.single.travelModes, ['DRIVE', 'WALK']);
    expect(place.containingPlaceIds, ['m1']);
  });

  test('highlightMatches bolds the typed part', () {
    final span = highlightMatches('Gateway Of India', const [TextMatch(0, 7)]);
    expect(span.children!.map((s) => (s as TextSpan).text), [
      'Gateway',
      ' Of India',
    ]);
    expect(span.children!.first.style!.fontWeight, FontWeight.w700);
  });

  test('searchNearby sends the circle, types and ranking', () async {
    final places = client((_) => <String, Object?>{});
    final results = await places.searchNearby(
      const LocationArea.circle(Coordinates(23.02, 72.57), 1000),
      includedTypes: ['cafe'],
      maxResults: 10,
      rankByDistance: true,
    );
    expect(results, isEmpty); // Google leaves out "places" when none match
    expect(body(requests.single), {
      'locationRestriction': {
        'circle': {
          'center': {'latitude': 23.02, 'longitude': 72.57},
          'radius': 1000.0,
        },
      },
      'includedTypes': ['cafe'],
      'maxResultCount': 10,
      'rankPreference': 'DISTANCE',
    });
  });

  test('photoUrl returns the URL without a redirect', () async {
    final places = client(
      (_) => {'photoUri': 'https://lh3.googleusercontent.com/photo'},
    );
    final url = await places.photoUrl(
      Place.fromJson(gateway).photos.single,
      maxWidth: 400,
    );
    expect(url, 'https://lh3.googleusercontent.com/photo');
    expect(
      requests.single.url.toString(),
      'https://places.googleapis.com/v1/places/ChIJgateway/photos/abc/media'
      '?maxWidthPx=400&skipHttpRedirect=true',
    );
  });

  group('geocoding', () {
    const result = {
      'status': 'OK',
      'results': [
        {
          'place_id': 'ChIJstreet',
          'formatted_address': 'Apollo Bandar, Colaba, Mumbai 400001, India',
          'geometry': {
            'location': {'lat': 18.922, 'lng': 72.8347},
            'location_type': 'ROOFTOP',
            'viewport': {
              'northeast': {'lat': 18.93, 'lng': 72.84},
              'southwest': {'lat': 18.91, 'lng': 72.82},
            },
          },
          'plus_code': {
            'compound_code': 'WRCM+RW Mumbai',
            'global_code': '7JCJWRCM+RW',
          },
          'types': ['street_address'],
          'address_components': [
            {
              'long_name': 'Mumbai',
              'short_name': 'Mumbai',
              'types': ['locality', 'political'],
            },
            {
              'long_name': 'India',
              'short_name': 'IN',
              'types': ['country', 'political'],
            },
          ],
        },
      ],
    };

    test('reverseGeocode sends lat,lng and reads the address', () async {
      final places = client((_) => result, languageCode: 'en');
      final results = await places.reverseGeocode(
        const Coordinates(18.922, 72.8347),
        resultTypes: ['street_address'],
      );
      final url = requests.single.url;
      expect(url.host, 'maps.googleapis.com');
      expect(url.queryParameters, {
        'latlng': '18.922,72.8347',
        'result_type': 'street_address',
        'language': 'en',
        'key': 'test-key',
      });
      final address = results.single;
      expect(address.formattedAddress, startsWith('Apollo Bandar'));
      expect(address.location, const Coordinates(18.922, 72.8347));
      expect(address.locationType, LocationType.rooftop);
      expect(address.viewport!.high, const Coordinates(18.93, 72.84));
      expect(address.plusCode!.compoundCode, 'WRCM+RW Mumbai');
      expect(address.addressComponents.city, 'Mumbai');
      expect(address.addressComponents.countryCode, 'IN');
    });

    test('geocode restricts to countries', () async {
      final places = client((_) => result);
      await places.geocode('Gateway of India', countries: ['IN']);
      expect(requests.single.url.queryParameters, {
        'address': 'Gateway of India',
        'components': 'country:IN',
        'key': 'test-key',
      });
    });

    test('no results is an empty list, not an error', () async {
      final places = client((_) => {'status': 'ZERO_RESULTS', 'results': []});
      expect(await places.geocode('nowhere at all'), isEmpty);
    });

    test('a disabled API is reported clearly', () async {
      final places = client(
        (_) => {
          'status': 'REQUEST_DENIED',
          'error_message': 'This API is not activated on your API project.',
        },
      );
      await expectLater(
        places.reverseGeocode(const Coordinates(0, 0)),
        throwsA(
          isA<PlacesException>()
              .having((e) => e.code, 'code', PlacesErrorCode.apiNotEnabled)
              .having((e) => e.reason, 'reason', 'REQUEST_DENIED'),
        ),
      );
    });
  });

  group('errors', () {
    Map<String, Object?> error(int code, String status, [String? reason]) => {
      'error': {
        'code': code,
        'message': 'Google message',
        'status': status,
        'details': [
          if (reason != null)
            {
              '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
              'reason': reason,
            },
        ],
      },
    };

    final cases = {
      PlacesErrorCode.invalidApiKey: (
        400,
        'INVALID_ARGUMENT',
        'API_KEY_INVALID',
      ),
      PlacesErrorCode.apiNotEnabled: (
        403,
        'PERMISSION_DENIED',
        'SERVICE_DISABLED',
      ),
      PlacesErrorCode.billingNotEnabled: (
        403,
        'PERMISSION_DENIED',
        'BILLING_DISABLED',
      ),
      PlacesErrorCode.keyRestricted: (
        403,
        'PERMISSION_DENIED',
        'API_KEY_ANDROID_APP_BLOCKED',
      ),
      PlacesErrorCode.quotaExceeded: (429, 'RESOURCE_EXHAUSTED', null),
      PlacesErrorCode.invalidRequest: (400, 'INVALID_ARGUMENT', null),
      PlacesErrorCode.notFound: (404, 'NOT_FOUND', null),
      PlacesErrorCode.server: (503, 'UNAVAILABLE', null),
    };

    for (final MapEntry(key: code, value: (status, name, reason))
        in cases.entries) {
      test('$name ${reason ?? ''} is ${code.name}', () async {
        final places = client(
          (_) => error(status, name, reason),
          status: status,
        );
        await expectLater(
          places.details('x'),
          throwsA(
            isA<PlacesException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.statusCode, 'statusCode', status)
                .having(
                  (e) => e.serverMessage,
                  'serverMessage',
                  'Google message',
                )
                .having((e) => e.message, 'message', code.description),
          ),
        );
      });
    }

    test('no connection is network, without the key in the message', () async {
      final places = GooglePlaces(
        apiKey: 'secret-key',
        httpClient: MockClient(
          (request) => throw http.ClientException(
            'Failed: ${request.url}?key=secret-key',
          ),
        ),
      );
      await expectLater(
        places.details('x'),
        throwsA(
          isA<PlacesException>()
              .having((e) => e.code, 'code', PlacesErrorCode.network)
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                isNot(contains('secret-key')),
              ),
        ),
      );
    });
  });

  test('app restriction headers are sent when given', () async {
    final places = client(
      (_) => gateway,
      androidPackageName: 'com.example.app',
      androidCertFingerprint: 'ab:cd:ef',
      iosBundleId: 'com.example.ios',
    );
    await places.details('x');
    expect(
      requests.single.headers,
      containsPair('X-Android-Package', 'com.example.app'),
    );
    expect(requests.single.headers, containsPair('X-Android-Cert', 'ABCDEF'));
    expect(
      requests.single.headers,
      containsPair('X-Ios-Bundle-Identifier', 'com.example.ios'),
    );
  });

  test('sessions have distinct UUID v4 tokens', () {
    final a = PlacesSession().token;
    final b = PlacesSession().token;
    expect(a, isNot(b));
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('distanceTo and formatDistance', () {
    const gatewayOfIndia = Coordinates(18.9220, 72.8347);
    const marineDrive = Coordinates(18.9440, 72.8231);
    expect(gatewayOfIndia.distanceTo(marineDrive), closeTo(2730, 30));
    expect(formatDistance(850), '850 m');
    expect(formatDistance(2730), '2.7 km');
    expect(formatDistance(12400), '12 km');
  });

  testWidgets('PlaceAutocompleteField suggests and picks a place', (
    tester,
  ) async {
    final places = client(
      (request) => request.url.path.endsWith('places:autocomplete')
          ? {
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'ChIJgateway',
                    'text': {'text': 'Gateway Of India, Mumbai'},
                    'structuredFormat': {
                      'mainText': {'text': 'Gateway Of India'},
                      'secondaryText': {'text': 'Mumbai'},
                    },
                  },
                },
              ],
            }
          : gateway,
    );
    Place? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceAutocompleteField(
            places: places,
            onSelected: (place) => picked = place,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'gate');
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, isEmpty); // still waiting for the user to pause
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Gateway Of India'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);

    await tester.tap(find.text('Gateway Of India'));
    await tester.pumpAndSettle();
    expect(picked?.name, 'Gateway Of India Mumbai');

    // Autocomplete and details shared one session.
    final token = jsonDecode(requests.first.body)['sessionToken'];
    expect(requests.last.url.queryParameters['sessionToken'], token);
  });

  const suggestionsJson = {
    'suggestions': [
      {
        'placePrediction': {
          'placeId': 'ChIJgateway',
          'text': {'text': 'Gateway Of India, Mumbai'},
          'structuredFormat': {
            'mainText': {'text': 'Gateway Of India'},
            'secondaryText': {'text': 'Mumbai'},
          },
        },
      },
    ],
  };

  Object? suggestOrDetails(http.Request request) =>
      request.url.path.endsWith('places:autocomplete')
      ? suggestionsJson
      : gateway;

  group('PlaceAutocompleteController', () {
    test('searches after a pause and keeps only the latest search', () async {
      final search = PlaceAutocompleteController(
        places: client(suggestOrDetails),
        debounce: const Duration(milliseconds: 20),
      );
      var notified = 0;
      search.addListener(() => notified++);

      final first = search.search('gat');
      final second = search.search('gate');
      expect(await first, isEmpty); // replaced by the second
      final suggestions = await second;

      expect(requests, hasLength(1));
      expect(body(requests.single)['input'], 'gate');
      expect(suggestions.single.mainText, 'Gateway Of India');
      expect(search.suggestions, suggestions);
      expect(search.query, 'gate');
      expect(search.loading, isFalse);
      expect(notified, greaterThan(0));

      final place = await search.select(suggestions.single);
      expect(place!.name, 'Gateway Of India Mumbai');
      expect(search.suggestions, isEmpty);
      expect(
        requests.last.url.queryParameters['sessionToken'],
        body(requests.first)['sessionToken'],
      );
      search.dispose();
    });

    test('short input clears without a request', () async {
      final search = PlaceAutocompleteController(
        places: client(suggestOrDetails),
        debounce: Duration.zero,
      );
      await search.search('gate');
      expect(search.suggestions, hasLength(1));
      expect(await search.search('g'), isEmpty);
      expect(search.suggestions, isEmpty);
      expect(requests, hasLength(1));
      search.dispose();
    });

    test('errors go to error and onError instead of throwing', () async {
      PlacesException? reported;
      final search = PlaceAutocompleteController(
        places: client(
          (_) => {
            'error': {
              'code': 400,
              'status': 'INVALID_ARGUMENT',
              'message': 'API key not valid.',
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                  'reason': 'API_KEY_INVALID',
                },
              ],
            },
          },
          status: 400,
        ),
        debounce: Duration.zero,
        onError: (e) => reported = e,
      );
      expect(await search.search('gate'), isEmpty);
      expect(search.error?.code, PlacesErrorCode.invalidApiKey);
      expect(reported, search.error);
      search.clear();
      expect(search.error, isNull);
      search.dispose();
    });
  });

  testWidgets('PlaceAutocompleteField uses custom builders', (tester) async {
    final places = client(suggestOrDetails);
    Place? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceAutocompleteField(
            places: places,
            onSelected: (place) => picked = place,
            fieldBuilder: (context, controller, focusNode, loading) =>
                TextField(
                  key: const Key('my-field'),
                  controller: controller,
                  focusNode: focusNode,
                ),
            suggestionBuilder: (context, suggestion, onSelected) => TextButton(
              onPressed: onSelected,
              child: Text('Go to ${suggestion.mainText}'),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('my-field')), 'gate');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Go to Gateway Of India'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);

    await tester.tap(find.text('Go to Gateway Of India'));
    await tester.pumpAndSettle();
    expect(picked?.name, 'Gateway Of India Mumbai');
  });
  group('GooglePlaces.instance', () {
    tearDown(() {
      if (GooglePlaces.isInitialized) GooglePlaces.instance.close();
    });

    test('throws a helpful error before initialize', () {
      expect(GooglePlaces.isInitialized, isFalse);
      expect(
        () => GooglePlaces.instance,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('GooglePlaces.initialize'),
          ),
        ),
      );
    });

    test('initialize sets it, again replaces it, close clears it', () {
      final first = GooglePlaces.initialize(apiKey: 'a');
      expect(GooglePlaces.instance, same(first));
      final second = GooglePlaces.initialize(apiKey: 'b', languageCode: 'hi');
      expect(GooglePlaces.instance, same(second));
      expect(GooglePlaces.instance.languageCode, 'hi');
      second.close();
      expect(GooglePlaces.isInitialized, isFalse);
    });

    testWidgets('widgets use the instance when no client is passed', (
      tester,
    ) async {
      requests = [];
      GooglePlaces.initialize(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(suggestOrDetails(request)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      Place? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceAutocompleteField(onSelected: (p) => picked = p),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'gate');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      // Keyboard: arrow down highlights, Enter picks.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(picked?.name, 'Gateway Of India Mumbai');
      expect(requests.first.headers['X-Goog-Api-Key'], 'test-key');
    });
  });

  testWidgets('the panel says when nothing is found', (tester) async {
    final places = client((_) => <String, Object?>{});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceAutocompleteField(places: places, onSelected: (_) {}),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'zzzzqq');
    await tester.pump();
    expect(find.byType(PlaceSuggestionSkeleton), findsWidgets);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No places found'), findsOneWidget);
    expect(find.byType(PlaceSuggestionSkeleton), findsNothing);
  });

  test('placeTypeIcon picks the first known type', () {
    expect(
      placeTypeIcon(['point_of_interest', 'cafe', 'food']),
      Icons.local_cafe_rounded,
    );
    expect(placeTypeIcon(['airport']), Icons.flight_rounded);
    expect(placeTypeIcon(['establishment']), Icons.place_rounded);
  });

  group('attribution', () {
    Future<void> search(
      WidgetTester tester,
      Widget field, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: field),
        ),
      );
      await tester.enterText(find.byType(TextField), 'gate');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Gateway Of India'), findsOneWidget);
    }

    testWidgets('is shown by default', (tester) async {
      final places = client(suggestOrDetails);
      await search(
        tester,
        PlaceAutocompleteField(places: places, onSelected: (_) {}),
      );
      expect(find.byType(GoogleMapsAttribution), findsOneWidget);
    });

    testWidgets('can be turned off for one widget', (tester) async {
      final places = client(suggestOrDetails);
      await search(
        tester,
        PlaceAutocompleteField(
          places: places,
          showAttribution: false,
          onSelected: (_) {},
        ),
      );
      expect(find.byType(GoogleMapsAttribution), findsNothing);
    });

    testWidgets('can be turned off app-wide with the theme', (tester) async {
      final places = client(suggestOrDetails);
      await search(
        tester,
        PlaceAutocompleteField(places: places, onSelected: (_) {}),
        theme: ThemeData(
          extensions: const [PlacesKitTheme(showAttribution: false)],
        ),
      );
      expect(find.byType(GoogleMapsAttribution), findsNothing);
    });
  });
}
