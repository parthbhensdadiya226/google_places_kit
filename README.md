# google_places_kit

[![pub package](https://img.shields.io/pub/v/google_places_kit.svg)](https://pub.dev/packages/google_places_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/parthbhensdadiya226/google_places_kit/blob/main/LICENSE)

Google Places and Geocoding for Flutter: place autocomplete, place details, nearby and text search, photos, and converting between coordinates and addresses. It uses **Places API (New)**, works on Android, iOS, web and desktop from the same code, and turns every response into typed Dart models.

This is an independent package, not an official Google plugin.

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/autocomplete.png" width="200" alt="Autocomplete suggestions for statue of lib, with place-type icons"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/place_details.png" width="200" alt="Statue of Liberty details with rating, contact and address parts"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/nearby.png" width="200" alt="Cafés near Times Square, nearest first"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/place_sheet.png" width="200" alt="A restaurant with price level, landmark, address parts and amenities"></td>
  </tr>
  <tr>
    <td align="center">Autocomplete</td>
    <td align="center">Place details</td>
    <td align="center">Nearby search</td>
    <td align="center">Full place</td>
  </tr>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/full_screen_search.png" width="200" alt="Full-screen search for museums in New York"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/custom_ui.png" width="200" alt="A custom search UI built on PlaceAutocompleteController"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/reverse_geocode.png" width="200" alt="Coordinates near the Empire State Building turned into an address"></td>
    <td align="center"><img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/geocode.png" width="200" alt="350 5th Ave, New York turned into coordinates"></td>
  </tr>
  <tr>
    <td align="center">Full-screen search</td>
    <td align="center">Your own UI</td>
    <td align="center">Lat/lng → address</td>
    <td align="center">Address → lat/lng</td>
  </tr>
</table>

```dart
GooglePlaces.initialize(apiKey: apiKey); // once, in main()

final places = GooglePlaces.instance;    // anywhere
final suggestions = await places.autocomplete('Gateway of In');
final place = await places.details(suggestions.first.placeId);
final cafes = await places.searchNearby(
  LocationArea.circle(place.location!, 1000),
  includedTypes: ['cafe'],
);
final addresses = await places.reverseGeocode(Coordinates(18.922, 72.834));
print(addresses.first.formattedAddress);
```

## Contents

- [Why this package](#-why-this-package)
- [Getting started](#-getting-started)
- [Methods](#-methods)
  - [autocomplete](#autocomplete) · [details](#details) · [searchText](#searchtext) · [searchNearby](#searchnearby) · [photoUrl](#photourl) · [reverseGeocode](#reversegeocode) · [geocode](#geocode)
- [Widgets](#-widgets)
- [Theming](#-theming)
- [Build your own UI](#%EF%B8%8F-build-your-own-ui)
- [Response models](#-response-models)
- [Choosing fields (PlaceField)](#-choosing-fields-placefield)
- [Errors](#%EF%B8%8F-errors)
- [Keeping the API key safe](#-keeping-the-api-key-safe)
- [Google's display rules](#-googles-display-rules)
- [Platforms](#-platforms)
- [Example](#example)

## 💡 Why this package

| | |
|---|---|
| **Places API (New)** | Google's current Places API. |
| **One codebase** | Pure Dart over HTTPS, so Android, iOS, web and desktop behave the same. No native setup. |
| **Typed models** | Every response becomes a Dart object: opening hours, reviews, photos, amenities, parking, payment, fuel prices, EV chargers, landmarks and more. No raw maps. |
| **Set up once** | `GooglePlaces.initialize()` in `main()`, then use it on any screen without passing it around. |
| **Modern widgets** | A rounded search field with a floating panel: icons for each kind of place, highlighted matches, loading skeletons, empty and error states, smooth animations, keyboard support, light and dark themes. |
| **Your UI or ours** | Restyle the widgets with one theme, swap parts with builders, use the UI-free `PlaceAutocompleteController`, or just the methods. |
| **Cheaper by default** | [Sessions](#what-is-a-session) group a search's requests, and field masks ask only for what you show. |
| **Clear errors** | A wrong key, a disabled API, missing billing or a restricted key each has its own error code and a plain-words message. |

## 🚀 Getting started

### Install

```yaml
dependencies:
  google_places_kit: ^0.1.0
```

### Google Cloud setup (once)

1. In [Google Cloud Console](https://console.cloud.google.com/), pick or create a project and **link a billing account**. Google requires one for these APIs, even within the free monthly usage.
2. In **APIs & Services → Library**, enable **Places API (New)**, and **Geocoding API** if you need coordinates ↔ addresses.
3. In **APIs & Services → Credentials**, create an **API key**. Under **API restrictions**, allow those two APIs.
4. Optional but wise: set a daily **quota** for each API and a **budget alert** in Billing.

Pass the key when you build, so it stays out of your code:

```bash
flutter run --dart-define=PLACES_API_KEY=your-api-key
```

### Initialize once

Call `GooglePlaces.initialize` in `main()`. Then any screen, service or widget can use `GooglePlaces.instance`, and the widgets use it without a `places:` argument.

```dart
void main() {
  GooglePlaces.initialize(
    apiKey: const String.fromEnvironment('PLACES_API_KEY'),
    languageCode: 'en',
    regionCode: 'IN',
  );
  runApp(const MyApp());
}

// Anywhere in the app:
final suggestions = await GooglePlaces.instance.autocomplete('pizza');

// Widgets need no client:
PlaceAutocompleteField(onSelected: (place) => print(place.name));
```

A service class works the same way:

```dart
class LocationService {
  final _places = GooglePlaces.instance;

  Future<String?> addressAt(Coordinates point) async {
    final results = await _places.reverseGeocode(point);
    return results.isEmpty ? null : results.first.formattedAddress;
  }
}
```

| Member | Description |
|---|---|
| `GooglePlaces.initialize(...)` | Creates the shared client. Takes the parameters below. Calling it again replaces it, for example when the user changes the app's language; requests already running finish on the old one. |
| `GooglePlaces.instance` | The shared client. Before `initialize`, it throws a `StateError` that says to call `initialize`. |
| `GooglePlaces.isInitialized` | Whether `initialize` was called. |

You can still create clients yourself with `GooglePlaces(apiKey: ...)`, for example with a second key, and pass them to the widgets with `places:`. Your own `GooglePlaces` objects are independent of the shared one.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | required | Your Google Maps Platform API key. |
| `languageCode` | `String?` | Google's choice | Language of names and addresses, such as `'en'` or `'hi'`. Each method can override it. |
| `regionCode` | `String?` | none | Two-letter country code, such as `'IN'`. Affects formatting and ranking, not which places are found. |
| `androidPackageName` | `String?` | none | For keys restricted to an Android app. See [key safety](#-keeping-the-api-key-safe). |
| `androidCertFingerprint` | `String?` | none | SHA-1 of the app's signing certificate, with or without colons. |
| `iosBundleId` | `String?` | none | For keys restricted to an iOS app. |
| `timeout` | `Duration` | 15 seconds | How long to wait before throwing `PlacesErrorCode.network`. |
| `httpClient` | `http.Client?` | a new client | Your own client, for example for tests. |

Call `close()` on a client you no longer need. Closing the shared instance also clears it, so only do that when the app no longer uses it.

The examples below use `places` for `GooglePlaces.instance` or your own client.

### Location permission

The package doesn't need location permission. It only sends web requests and never reads the device's location, so an app that just searches places or addresses needs no extra setup.

To show results near the user, get their position with a package such as [`geolocator`](https://pub.dev/packages/geolocator) (which adds the location permission to your app), then pass it in:

```dart
final position = await Geolocator.getCurrentPosition();
final here = Coordinates(position.latitude, position.longitude);

places.autocomplete(text, locationBias: LocationArea.circle(here, 5000), origin: here);
places.searchNearby(LocationArea.circle(here, 1000), includedTypes: ['cafe']);
places.reverseGeocode(here);
```

The example app does this for its "My location" buttons.

## 🧭 Methods

Every method throws a [`PlacesException`](#%EF%B8%8F-errors) when the request fails.

### autocomplete

Suggestions for what the user is typing, such as "Gateway Of India" for "gateway of in".

```dart
Future<List<PlaceSuggestion>> autocomplete(String input, {...})
```

| Parameter | Type | Description |
|---|---|---|
| `input` | `String` | What the user typed. Empty input returns `[]` without a request. |
| `session` | `PlacesSession?` | Groups the requests of one search for billing. See below. |
| `locationBias` | `LocationArea?` | Prefer places in this circle or rectangle. |
| `locationRestriction` | `LocationArea?` | Only places in this area. Use this or `locationBias`. |
| `types` | `List<String>` | Up to five place types, such as `['restaurant']`, or `['(cities)']` and `['(regions)']`. |
| `countries` | `List<String>` | Up to 15 country codes, such as `['IN', 'NP']`. |
| `origin` | `Coordinates?` | Adds `distanceMeters` from here to each suggestion. |
| `languageCode`, `regionCode` | `String?` | Override the client's defaults. |

**Returns** a list of [`PlaceSuggestion`](#placesuggestion).

```dart
var session = PlacesSession();

final suggestions = await places.autocomplete(
  'pizza hut colaba',
  session: session,
  locationBias: LocationArea.circle(userLocation, 20000),
  origin: userLocation,
);
for (final s in suggestions) {
  print('${s.mainText} — ${s.secondaryText} (${s.distanceMeters} m)');
}

// When the user picks one, end the session with details():
final place = await places.details(suggestions.first.placeId, session: session);
session = PlacesSession(); // a new one for the next search
```

#### What is a session?

When a user types "statue of lib", your app may call `autocomplete` several times, once for each pause in typing. A **session** tells Google that all those calls, plus the `details` call for the place the user finally picks, belong to **one search**.

```text
user types "sta"     → autocomplete(session: A)  ┐
user types "statue"  → autocomplete(session: A)  │ one session (A)
user types "statue o"→ autocomplete(session: A)  │
user picks a result  → details(session: A)       ┘ session A ends here
next search          → autocomplete(session: B)  ← a new session
```

**Why it matters: billing.** With a session that ends in a `details` call, Google bills the search as one session plus the details request, instead of charging every autocomplete call on its own. Without a session, each keystroke request is billed separately, which adds up quickly in a search box. See Google's [Places API usage and billing](https://developers.google.com/maps/documentation/places/web-service/usage-and-billing) page for current prices.

**How it works:** a session is a random ID (a version 4 UUID) sent with each request. `PlacesSession()` creates one.

**Rules:**

1. Create a new `PlacesSession` when the user starts a new search.
2. Pass the same session to every `autocomplete` call of that search.
3. Pass it to the `details` call for the place the user picks. That ends the session.
4. Never reuse a session after its `details` call, and never share one between users.
5. If the user leaves without picking anything, just make a new session next time. Those requests are billed one by one, as if there were no session.

Sessions are only for `autocomplete` followed by `details`. `searchText`, `searchNearby`, photos and geocoding don't use them.

**You don't need to do this yourself** if you use `PlaceAutocompleteField`, `showPlaceSearch` or `PlaceAutocompleteController`: they create a session per search, pass it along, and start a new one after each pick.

### details

The full place for a place ID, with the fields you ask for.

```dart
Future<Place> details(String placeId, {...})
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `placeId` | `String` | required | From a suggestion, a search result or a geocoding result. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | What to get. Google bills by the most expensive field. See [PlaceField](#-choosing-fields-placefield). |
| `session` | `PlacesSession?` | none | The autocomplete session this ends. |
| `languageCode`, `regionCode` | `String?` | client's | Override the client's defaults. |

**Returns** a [`Place`](#place). Only the fields you asked for are set.

```dart
final place = await places.details(placeId, fields: PlaceField.details);
print(place.name);              // Gateway Of India Mumbai
print(place.rating);            // 4.6
print(place.openNow);           // true
print(place.addressComponents.city); // Mumbai
```

### searchText

Places matching a text query, like the Google Maps search box: "pizza", "petrol pump near Andheri", "hotels in Goa".

```dart
Future<PlaceSearchResults> searchText(String query, {...})
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `query` | `String` | required | What to search for. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | What to get for each place. |
| `locationBias` | `LocationArea?` | none | Prefer places in this circle or rectangle. |
| `locationRestriction` | `LocationArea?` | none | Only places in this **rectangle**. |
| `includedType` | `String?` | none | Only this type, such as `'restaurant'`. |
| `openNow` | `bool` | `false` | Only places open right now. |
| `minRating` | `double?` | none | Only places rated at least this (0 to 5). |
| `maxResults` | `int?` | 20 | Results per page, 1 to 20. |
| `pageToken` | `String?` | none | `nextPageToken` from the previous page. |
| `languageCode`, `regionCode` | `String?` | client's | Override the client's defaults. |

**Returns** [`PlaceSearchResults`](#placesearchresults): a normal `List<Place>` with a `nextPageToken` for more results (up to 60 in total).

```dart
final page1 = await places.searchText(
  'pizza',
  locationBias: LocationArea.circle(userLocation, 5000),
  openNow: true,
  minRating: 4,
  fields: [PlaceField.id, PlaceField.displayName, PlaceField.rating],
);
if (page1.nextPageToken != null) {
  final page2 = await places.searchText(
    'pizza',
    locationBias: LocationArea.circle(userLocation, 5000),
    openNow: true,
    minRating: 4,
    fields: [PlaceField.id, PlaceField.displayName, PlaceField.rating],
    pageToken: page1.nextPageToken,
  );
}
```

### searchNearby

Places of certain types in a circle, such as ATMs within a kilometer.

```dart
Future<List<Place>> searchNearby(LocationArea area, {...})
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `area` | `LocationArea` | required | A `LocationArea.circle(center, radiusMeters)`, radius up to 50,000 m. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | What to get for each place. |
| `includedTypes` | `List<String>` | all | Only these types, such as `['cafe', 'bakery']`. |
| `excludedTypes` | `List<String>` | none | Leave these types out. |
| `maxResults` | `int?` | 20 | 1 to 20. |
| `rankByDistance` | `bool` | `false` | Nearest first. Otherwise most popular first. |
| `languageCode`, `regionCode` | `String?` | client's | Override the client's defaults. |

**Returns** up to 20 [`Place`](#place)s.

```dart
final atms = await places.searchNearby(
  LocationArea.circle(userLocation, 1000),
  includedTypes: ['atm'],
  rankByDistance: true,
);
for (final atm in atms) {
  print('${atm.name}: ${formatDistance(userLocation.distanceTo(atm.location!))}');
}
```

### photoUrl

An image URL for a place photo.

```dart
Future<String> photoUrl(PlacePhoto photo, {int? maxWidth = 800, int? maxHeight})
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `photo` | `PlacePhoto` | required | From `place.photos` (ask for `PlaceField.photos`). |
| `maxWidth` | `int?` | 800 | Maximum width, 1 to 4800 pixels. |
| `maxHeight` | `int?` | none | Maximum height, 1 to 4800 pixels. The photo keeps its shape. |

**Returns** the URL. It doesn't contain your API key, so it's safe to cache.

```dart
final url = await places.photoUrl(place.photos.first, maxWidth: 600);
Image.network(url);
Text('Photo: ${place.photos.first.authorAttributions.first.displayName}');
```

### reverseGeocode

The addresses at a latitude and longitude, for "use my location". Uses the Geocoding API.

```dart
Future<List<GeocodingResult>> reverseGeocode(Coordinates location, {...})
```

| Parameter | Type | Description |
|---|---|---|
| `location` | `Coordinates` | Where. |
| `resultTypes` | `List<String>` | Only these types, such as `['street_address']` or `['locality']`. |
| `languageCode`, `regionCode` | `String?` | Override the client's defaults. |

**Returns** [`GeocodingResult`](#geocodingresult)s, most precise first: usually the street address, then the area, city, state and country. No address there (such as at sea) returns `[]`.

```dart
final results = await places.reverseGeocode(Coordinates(18.922, 72.8347));
final address = results.first;
print(address.formattedAddress);             // ..., Colaba, Mumbai 400001, India
print(address.addressComponents.postalCode); // 400001
print(address.locationType);                 // LocationType.rooftop
```

### geocode

The coordinates of an address. Uses the Geocoding API.

```dart
Future<List<GeocodingResult>> geocode(String address, {...})
```

| Parameter | Type | Description |
|---|---|---|
| `address` | `String` | The address or place name. |
| `countries` | `List<String>` | Only results in these countries, such as `['IN']`. |
| `languageCode`, `regionCode` | `String?` | Override the client's defaults. |

**Returns** [`GeocodingResult`](#geocodingresult)s, best match first. No match returns `[]`.

```dart
final results = await places.geocode(
  'Shahid Bhagat Singh Rd, Colaba, Mumbai 400005',
  countries: ['IN'],
);
print(results.first.location);     // Coordinates(18.91..., 72.82...)
print(results.first.locationType); // how exact it is
```

Geocoding is made for **addresses**. For the name of a place or business, such as "Taj Mahal" or "Pizza Hut Colaba", use [`searchText`](#searchtext) or [`autocomplete`](#autocomplete): geocoding may only find the city, with `LocationType.approximate`.

## 🧩 Widgets

The widgets are optional. Use them as they are, restyle them with a [theme](#-theming), swap parts with builders, or skip them and [build your own UI](#%EF%B8%8F-build-your-own-ui). All of them use `GooglePlaces.instance` unless you pass `places:`.

### PlaceAutocompleteField

A rounded search field that suggests places in a floating panel while the user types, and gives you the full `Place` when they pick one.

- Each suggestion has an icon for its kind of place (plane, fork and knife, coffee cup, hotel, temple, road and more), the typed part highlighted, and the distance when you give an `origin`.
- While it loads, the panel shows a shimmering skeleton. It says "No places found" when nothing matches, and shows the error when a request fails.
- The panel and rows animate in. Arrow keys, Enter and Escape work on web and desktop.
- It waits for a pause in typing, uses one [session](#what-is-a-session) per search, and shows the "Google Maps" attribution Google requires (see [display rules](#-googles-display-rules)).

```dart
PlaceAutocompleteField(
  fields: PlaceField.address,
  options: const PlaceAutocompleteOptions(countries: ['IN']),
  onSelected: (place) => print(place.formattedAddress),
  onError: (error) => print(error.message),
)
```

| Property | Type | Default | Description |
|---|---|---|---|
| `onSelected` | `ValueChanged<Place>` | required | Called with the picked place. |
| `places` | `GooglePlaces?` | `GooglePlaces.instance` | The client. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | Fields to get for the picked place. |
| `options` | `PlaceAutocompleteOptions` | no filters | Filters for the suggestions (below). |
| `hintText` | `String` | "Search for a place" | The hint in the default field. |
| `debounce` | `Duration` | 300 ms | Wait after the last keystroke before asking Google. |
| `minLength` | `int` | 2 | Characters needed before suggestions start. |
| `onError` | `ValueChanged<PlacesException>?` | none | Called when a request fails. The panel also shows the error. |
| `controller` | `TextEditingController?` | own | To read or set the text. |
| `focusNode` | `FocusNode?` | own | The field's focus node. |
| `autofocus` | `bool` | `false` | Focus the field when it appears. |
| `enabled` | `bool` | `true` | Whether the field can be used. |
| **Look** | | | |
| `decoration` | `InputDecoration?` | rounded and filled, from the [theme](#-theming) | Replaces the field's look. A clear button or spinner replaces the suffix icon while there is text. |
| `style` | `TextStyle?` | theme | The typed text. |
| `optionsMaxHeight` | `double` | 380 | The tallest the panel gets. |
| `showAttribution` | `bool?` | `true` (from the theme) | The "Google Maps" label under results. See [display rules](#-googles-display-rules). |
| **Builders** | | | |
| `fieldBuilder` | `(context, controller, focusNode, loading) → Widget` | none | Your own text field. Use the given controller and focus node; the search follows the controller's text, so no other wiring is needed. |
| `suggestionBuilder` | `(context, suggestion, onSelected) → Widget` | `PlaceSuggestionTile` | Your own row for each suggestion. The panel, its states and the attribution stay. |
| `suggestionsViewBuilder` | `(context, suggestions, onSelected) → Widget` | `PlaceSuggestionsPanel` | The whole panel. Add `GoogleMapsAttribution` yourself. |

Colors, corners and shadows come from [`PlacesKitTheme`](#-theming).

A restyled field with your own rows:

```dart
PlaceAutocompleteField(
  onSelected: (place) => setState(() => _place = place),
  decoration: InputDecoration(
    hintText: 'Pickup location',
    prefixIcon: const Icon(Icons.my_location),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  suggestionBuilder: (context, suggestion, onSelected) => ListTile(
    leading: const Icon(Icons.local_taxi),
    title: Text(suggestion.mainText),
    subtitle: Text(suggestion.secondaryText),
    onTap: onSelected,
  ),
)
```

### PlaceAutocompleteOptions

Filters used by the widgets and `PlaceAutocompleteController`, matching the [`autocomplete`](#autocomplete) parameters:

| Property | Type | Description |
|---|---|---|
| `locationBias` | `LocationArea?` | Prefer places in this area. |
| `locationRestriction` | `LocationArea?` | Only places in this area. |
| `types` | `List<String>` | Up to five place types. |
| `countries` | `List<String>` | Up to 15 country codes. |
| `origin` | `Coordinates?` | Show each suggestion's distance from here. |

### showPlaceSearch and PlaceSearchPage

A full-screen search, nicer on phones and handy for "choose a location" buttons. It has the same rounded field, a friendly empty state before the user types, a skeleton while loading, and "No places found" and error states. On wide screens the content stays at a comfortable width. Returns the picked place, or `null` if the user goes back.

```dart
final place = await showPlaceSearch(
  context,
  fields: PlaceField.details,
  hintText: 'Where to?',
);
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | required | For navigation. |
| `places` | `GooglePlaces?` | `GooglePlaces.instance` | The client. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | Fields to get for the picked place. |
| `options` | `PlaceAutocompleteOptions` | no filters | Filters for the suggestions. |
| `hintText` | `String` | "Search for a place" | The search field's hint. |
| `suggestionBuilder` | `(context, suggestion, onSelected) → Widget` | `PlaceSuggestionTile` | Your own row for each suggestion. |
| `errorBuilder` | `(context, error) → Widget` | an icon with the error message | What to show when a request fails. |
| `emptyBuilder` | `WidgetBuilder?` | "Find a place" with an icon | What to show before the user types, such as recent searches. |
| `showAttribution` | `bool?` | `true` (from the theme) | The "Google Maps" label under results. See [display rules](#-googles-display-rules). |

`PlaceSearchPage` is the page itself, for your own routes. It also takes `debounce` and `minLength`.

### Helpers

| Helper | Description |
|---|---|
| `PlaceSuggestionsPanel(controller:, onSelected:)` | The floating panel with all its states, for your own field with a `PlaceAutocompleteController`. Takes `highlightedIndex`, `suggestionBuilder`, `maxHeight` and `showAttribution`. |
| `PlaceSuggestionTile(suggestion:, onTap:)` | A suggestion row: place-type icon, highlighted name, address, distance pill. Change it with `highlighted`, `leading`, `showIcon`, `trailing`, `showDistance`, `titleStyle`, `matchStyle` and `subtitleStyle`. |
| `PlaceSuggestionSkeleton()` | A shimmering placeholder row for loading states. It stays still when the system asks for reduced motion. |
| `PlaceTypeIcon(types:, size:)` | The rounded, tinted icon for a kind of place. Works with `suggestion.types` and `place.types`. |
| `placeTypeIcon(types)` | Just the `IconData`, for your own widgets. |
| `GoogleMapsAttribution()` | The "Google Maps" label Google requires with results shown without a map. Takes `style`, `padding` and `alignment`. |
| `highlightMatches(text, matches, {style, matchStyle})` | A `TextSpan` with the matched parts in `matchStyle` (bold by default). |
| `formatDistance(meters)` | "850 m" or "2.4 km". |

## 🎨 Theming

The widgets take their colors from your app's `ColorScheme`, so they match your brand, and light and dark mode, with no setup. To change their look everywhere at once, add a `PlacesKitTheme` to your `ThemeData`. Every value is optional.

```dart
MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: Colors.teal,
    extensions: const [
      PlacesKitTheme(
        fieldBorderRadius: BorderRadius.all(Radius.circular(12)),
        panelBorderRadius: BorderRadius.all(Radius.circular(16)),
        matchColor: Colors.deepOrange,
      ),
    ],
  ),
)
```

| Property | Default | Used for |
|---|---|---|
| `fieldColor` | `surfaceContainerHigh` | Search field background. |
| `fieldBorderRadius` | fully rounded | Search field corners. |
| `fieldFocusColor` | `primary` | Search field outline while focused. |
| `panelColor` | `surfaceContainerLow` | Suggestion panel background. |
| `panelBorderColor` | faint `outlineVariant` | Thin outline around the panel. |
| `panelBorderRadius` | 20 | Panel corners. |
| `panelShadows` | soft, wide shadow | Panel shadow. Pass `[]` for none. |
| `iconBackgroundColor` | `primaryContainer` | Place-type icon background. |
| `iconColor` | `onPrimaryContainer` | Place-type icon. |
| `matchColor` | `primary` | The typed part of each suggestion. |
| `highlightColor` | light `primary` tint | The row chosen with the arrow keys. |
| `titleStyle` | `bodyLarge`, medium weight | Suggestion names. |
| `subtitleStyle` | `bodySmall`, muted | Suggestion addresses. |
| `showAttribution` | `true` | The "Google Maps" label under results. See [display rules](#-googles-display-rules) before turning it off. |

Use a different theme for one widget by wrapping it in `Theme(data: Theme.of(context).copyWith(extensions: [...]))`. Read the resolved values in your own widgets with `PlacesKitTheme.of(context)`.

## 🛠️ Build your own UI

You don't need the widgets. There are two ways to use your own design.

### Option 1: call the methods

Everything the widgets do is a public method that returns typed models. Use them from any widget, state management or plain Dart code:

```dart
class MySearch extends StatefulWidget {
  const MySearch({super.key});

  @override
  State<MySearch> createState() => _MySearchState();
}

class _MySearchState extends State<MySearch> {
  final _places = GooglePlaces.instance;
  var _session = PlacesSession();
  var _suggestions = <PlaceSuggestion>[];
  Timer? _debounce;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions = await _places.autocomplete(
          text,
          session: _session,
        );
        if (mounted) setState(() => _suggestions = suggestions);
      } on PlacesException catch (e) {
        print(e.message);
      }
    });
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {
    final place = await _places.details(
      suggestion.placeId,
      fields: PlaceField.address,
      session: _session,
    );
    _session = PlacesSession();
    print(place.formattedAddress);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(onChanged: _onChanged),
      for (final s in _suggestions)
        ListTile(title: Text(s.mainText), onTap: () => _pick(s)),
      if (_suggestions.isNotEmpty) const GoogleMapsAttribution(),
    ],
  );
}
```

Remember the parts the widgets would handle: wait for a pause in typing, reuse one `PlacesSession` until `details`, catch `PlacesException`, and show the attribution.

### Option 2: PlaceAutocompleteController

`PlaceAutocompleteController` is the widgets' search logic with no UI. It waits for a pause in typing, manages the session, ignores answers to older searches, and keeps `suggestions`, `loading` and `error` for you. It's a `ChangeNotifier`, so rebuild with `ListenableBuilder`, `AnimatedBuilder`, or your state management.

Want our panel under your own field? Put a `PlaceSuggestionsPanel(controller: search, onSelected: ...)` below it.

```dart
late final search = PlaceAutocompleteController(
  fields: PlaceField.details,
  options: const PlaceAutocompleteOptions(countries: ['IN']),
);

@override
Widget build(BuildContext context) => ListenableBuilder(
  listenable: search,
  builder: (context, _) => Column(
    children: [
      SearchBar(
        hintText: 'Where to?',
        onChanged: search.search,
        trailing: [if (search.loading) const CircularProgressIndicator()],
      ),
      if (search.error case final error?) Text(error.message),
      if (search.hasNoResults) const Text('No places found'),
      for (final suggestion in search.suggestions)
        MyPlaceCard(
          suggestion: suggestion,
          onTap: () async {
            final place = await search.select(suggestion);
            if (place != null) print(place.name);
          },
        ),
      if (search.suggestions.isNotEmpty) const GoogleMapsAttribution(),
    ],
  ),
);

@override
void dispose() {
  search.dispose();
  super.dispose();
}
```

| Constructor parameter | Type | Default | Description |
|---|---|---|---|
| `places` | `GooglePlaces?` | `GooglePlaces.instance` | The client. |
| `options` | `PlaceAutocompleteOptions` | no filters | Filters. Can be changed later, for example once the location is known. |
| `fields` | `List<PlaceField>` | `PlaceField.basic` | Fields `select` gets. |
| `debounce` | `Duration` | 300 ms | Wait after the last keystroke. |
| `minLength` | `int` | 2 | Characters needed before searching. |
| `onError` | `ValueChanged<PlacesException>?` | none | Called when a request fails. |

| Member | Description |
|---|---|
| `search(text)` | Call on every keystroke. Searches once the user pauses. Returns the suggestions, or `[]` if a newer search replaced it or it failed. Never throws. |
| `select(suggestion, {fields})` | Gets the full `Place`, ends the session and clears the query and suggestions. Returns `null` if it failed. |
| `clear()` | Clears the query, suggestions and error, and cancels a pending search. |
| `suggestions` | `List<PlaceSuggestion>` for the latest search. |
| `query` | The latest search text, trimmed. |
| `loading` | `true` from the first keystroke until the suggestions arrive, and while a picked place is fetched. Use it for a spinner or skeleton. |
| `error` | The latest `PlacesException`, or `null`. |
| `hasNoResults` | `true` when Google found nothing for `query`, for a "No places found" message. |
| `dispose()` | Call when you're done with it. |

The example app's **Your own UI** page is built this way.

## 📦 Response models

Every response is turned into these classes. Fields Google didn't send, or that you didn't ask for, are `null` or empty.

### PlaceSuggestion

From `autocomplete`.

| Field | Type | Example / description |
|---|---|---|
| `placeId` | `String` | Pass to `details`. |
| `text` | `String` | "Gateway Of India, Apollo Bandar, Colaba, Mumbai, India" |
| `mainText` | `String` | "Gateway Of India" |
| `secondaryText` | `String` | "Apollo Bandar, Colaba, Mumbai, India" |
| `textMatches`, `mainTextMatches`, `secondaryTextMatches` | `List<TextMatch>` | Where the text matches the input (`start`, `end`), for bold highlighting. |
| `types` | `List<String>` | `['tourist_attraction', ...]` |
| `distanceMeters` | `int?` | Distance from `origin`, if given. |

### Place

From `details`, `searchText` and `searchNearby`. The field to ask for is in brackets.

**Basics and address**

| Field | Type | Example / description |
|---|---|---|
| `id` | `String` | The place ID (`id`). |
| `name` | `String?` | "Gateway Of India Mumbai" (`displayName`) |
| `formattedAddress` | `String?` | Full address (`formattedAddress`) |
| `shortAddress` | `String?` | Without country and postal code (`shortAddress`) |
| `postalAddress` | [`PostalAddress?`](#postaladdress) | Standard postal format (`postalAddress`) |
| `adrFormatAddress` | `String?` | Address in adr microformat HTML (`adrFormatAddress`) |
| `addressComponents` | `List<AddressComponent>` | Address parts, with [`city`, `state`, …](#addresscomponent-and-address-parts) getters (`addressComponents`) |
| `addressDescriptor` | [`AddressDescriptor?`](#addressdescriptor) | Nearby landmarks and areas (`addressDescriptor`) |
| `location` | `Coordinates?` | Latitude and longitude (`location`) |
| `viewport` | `Viewport?` | Area to show on a map (`viewport`) |
| `plusCode` | `PlusCode?` | "7JCJWRCM+QV" (`plusCode`) |
| `timeZone` | `String?` | "Asia/Calcutta" (`timeZone`) |
| `utcOffsetMinutes` | `int?` | 330 (`utcOffsetMinutes`) |

**Type and status**

| Field | Type | Example / description |
|---|---|---|
| `types` | `List<String>` | `['pizza_restaurant', 'restaurant', 'food']` (`types`) |
| `primaryType` | `String?` | `'pizza_restaurant'` (`primaryType`) |
| `primaryTypeLabel` | `String?` | "Pizza restaurant" (`primaryTypeLabel`) |
| `googleMapsTypeLabel` | `String?` | "Pizza Restaurant", as Google Maps shows it (`googleMapsTypeLabel`) |
| `businessStatus` | `BusinessStatus?` | `operational`, `closedTemporarily`, `closedPermanently` (`businessStatus`) |
| `pureServiceAreaBusiness` | `bool?` | True for businesses with no shop to visit (`pureServiceAreaBusiness`) |
| `iconMaskBaseUri` | `String?` | Icon URL; add `.svg` or `.png` (`iconMaskBaseUri`) |
| `iconBackgroundColor` | `String?` | "#FF9E67" (`iconBackgroundColor`) |
| `containingPlaceIds` | `List<String>` | Places it is in, such as a mall (`containingPlaces`) |
| `subDestinationIds` | `List<String>` | Places inside it, such as terminals (`subDestinations`) |

**Contact and links**

| Field | Type | Example / description |
|---|---|---|
| `phoneNumber` | `String?` | Local format (`phoneNumber`) |
| `internationalPhoneNumber` | `String?` | "+91 22 …" (`internationalPhoneNumber`) |
| `websiteUri` | `String?` | (`websiteUri`) |
| `googleMapsUri` | `String?` | Opens the place in Google Maps (`googleMapsUri`) |
| `googleMapsLinks` | [`GoogleMapsLinks?`](#googlemapslinks) | Directions, reviews, photos, write a review (`googleMapsLinks`) |
| `navigationPoints` | `List<NavigationPoint>` | Where to stop when driving or walking there: `name`, `location`, `travelModes` |

**Ratings, price and hours**

| Field | Type | Example / description |
|---|---|---|
| `rating` | `double?` | 4.6 (`rating`) |
| `userRatingCount` | `int?` | 388483 (`userRatingCount`) |
| `priceLevel` | `PriceLevel?` | `free`, `inexpensive`, `moderate`, `expensive`, `veryExpensive` (`priceLevel`) |
| `priceRange` | `PriceRange?` | `start` and `end` as [`Money`](#money) (`priceRange`) |
| `openNow` | `bool?` | From the current or regular hours |
| `openingHours` | [`OpeningHours?`](#openinghours) | Usual weekly hours (`openingHours`) |
| `currentOpeningHours` | [`OpeningHours?`](#openinghours) | The coming week, with holidays (`currentOpeningHours`) |
| `secondaryOpeningHours`, `currentSecondaryOpeningHours` | `List<OpeningHours>` | Hours of the drive-through, delivery, kitchen… (`secondaryOpeningHours`, `currentSecondaryOpeningHours`) |

**Photos, reviews and summaries**

| Field | Type | Example / description |
|---|---|---|
| `photos` | [`List<PlacePhoto>`](#placephoto) | Up to 10 (`photos`) |
| `reviews` | [`List<PlaceReview>`](#placereview) | Up to 5 (`reviews`) |
| `editorialSummary` | `String?` | A short description by Google (`editorialSummary`) |
| `generativeSummary` | [`AiSummary?`](#aisummary) | AI overview of the place (`generativeSummary`) |
| `reviewSummary` | [`AiSummary?`](#aisummary) | AI summary of the reviews (`reviewSummary`) |

**What it offers**

| Field | Type | Description |
|---|---|---|
| `amenities` | [`PlaceAmenities`](#placeamenities) | Delivery, dine-in, vegetarian food, outdoor seating, … |
| `accessibility` | [`AccessibilityOptions?`](#accessibilityoptions-parkingoptions-paymentoptions) | Wheelchair access (`accessibilityOptions`) |
| `parking` | [`ParkingOptions?`](#accessibilityoptions-parkingoptions-paymentoptions) | Parking (`parkingOptions`) |
| `payment` | [`PaymentOptions?`](#accessibilityoptions-parkingoptions-paymentoptions) | Cards, cash only, tap to pay (`paymentOptions`) |
| `fuelOptions` | [`FuelOptions?`](#fueloptions-and-evchargeoptions) | Fuel prices at petrol pumps (`fuelOptions`) |
| `evChargeOptions` | [`EvChargeOptions?`](#fueloptions-and-evchargeoptions) | Chargers at EV stations (`evChargeOptions`) |
| `json` | `Map<String, Object?>` | The raw response, for any field not listed here |

### PlaceAmenities

`place.amenities`. Each is `bool?`: `true`, `false`, or `null` when Google doesn't know. Ask for each with the `PlaceField` of the same name.

`delivery`, `dineIn`, `takeout`, `curbsidePickup`, `reservable`, `servesBreakfast`, `servesBrunch`, `servesLunch`, `servesDinner`, `servesVegetarianFood`, `servesDessert`, `servesCoffee`, `servesBeer`, `servesWine`, `servesCocktails`, `outdoorSeating`, `liveMusic`, `menuForChildren`, `goodForChildren`, `goodForGroups`, `goodForWatchingSports`, `allowsDogs`, `restroom`.

```dart
if (place.amenities.servesVegetarianFood ?? false) print('Veg options');
```

### AccessibilityOptions, ParkingOptions, PaymentOptions

All fields are `bool?`.

| Class | Fields |
|---|---|
| `AccessibilityOptions` | `wheelchairAccessibleEntrance`, `wheelchairAccessibleParking`, `wheelchairAccessibleRestroom`, `wheelchairAccessibleSeating` |
| `ParkingOptions` | `freeParkingLot`, `paidParkingLot`, `freeStreetParking`, `paidStreetParking`, `freeGarageParking`, `paidGarageParking`, `valetParking` |
| `PaymentOptions` | `acceptsCreditCards`, `acceptsDebitCards`, `acceptsCashOnly`, `acceptsNfc` (tap to pay) |

### OpeningHours

| Field | Type | Description |
|---|---|---|
| `openNow` | `bool?` | Open right now. |
| `weekdayDescriptions` | `List<String>` | "Monday: 11:00 AM – 11:00 PM", one per day, in the request's language. |
| `periods` | `List<OpeningPeriod>` | Each has `open` and `close` (`null` close means open 24 hours). |
| `nextOpenTime` | `DateTime?` | When it next opens (UTC), if closed now. |
| `nextCloseTime` | `DateTime?` | When it next closes (UTC), if open now. |
| `type` | `String?` | For secondary hours: `DRIVE_THROUGH`, `DELIVERY`, `TAKEOUT`, `KITCHEN`, `BREAKFAST`, … |

`OpeningTime` (in `open` and `close`): `day` (0 = Sunday … 6 = Saturday), `hour`, `minute`, and `date` for current hours.

### PlacePhoto

| Field | Type | Description |
|---|---|---|
| `name` | `String` | Photo reference; pass the photo to `photoUrl`. |
| `widthPx`, `heightPx` | `int` | Largest available size. |
| `authorAttributions` | `List<AuthorAttribution>` | Who took it: `displayName`, `uri`, `photoUri`. **Show it with the photo.** |
| `googleMapsUri` | `String?` | Opens the photo in Google Maps. |
| `flagContentUri` | `String?` | Where users can report it. |

### PlaceReview

| Field | Type | Description |
|---|---|---|
| `author` | `AuthorAttribution` | `displayName`, `uri`, `photoUri`. **Show it with the review.** |
| `rating` | `double?` | 1 to 5. |
| `text` | `String?` | Translated to the request's language if needed. |
| `originalText` | `String?` | As the author wrote it. |
| `languageCode` | `String?` | Language of `text`. |
| `relativeTime` | `String?` | "4 months ago". |
| `publishTime` | `DateTime?` | When it was published (UTC). |
| `googleMapsUri`, `flagContentUri` | `String?` | Open it in Google Maps; report it. |

### AiSummary

`place.generativeSummary` and `place.reviewSummary`.

| Field | Type | Description |
|---|---|---|
| `text` | `String` | The summary. |
| `disclosureText` | `String?` | "Summarized with Gemini". **Show it with the summary.** |
| `flagContentUri` | `String?` | Where users can report it. |
| `reviewsUri` | `String?` | For review summaries: opens the reviews. |

### GoogleMapsLinks

`placeUri`, `directionsUri`, `reviewsUri`, `writeAReviewUri`, `photosUri`: all `String?`.

```dart
launchUrl(Uri.parse(place.googleMapsLinks!.directionsUri!)); // with url_launcher
```

### AddressDescriptor

Where the place is, in words people use.

| Field | Type | Description |
|---|---|---|
| `landmarks` | `List<Landmark>` | `name`, `placeId`, `types`, `spatialRelationship` (`NEAR`, `ACROSS_THE_ROAD`, `DOWN_THE_ROAD`, `AROUND_THE_CORNER`, `BESIDE`, `BEHIND`, `WITHIN`), `straightLineDistanceMeters`, `travelDistanceMeters` |
| `areas` | `List<AddressArea>` | `name`, `placeId`, `containment` (`WITHIN`, `OUTSKIRTS`, `NEAR`) |

```dart
final landmark = place.addressDescriptor!.landmarks.first;
print('${landmark.spatialRelationship} ${landmark.name}'); // ACROSS_THE_ROAD Sassoon Dock
```

### FuelOptions and EvChargeOptions

| Class | Fields |
|---|---|
| `FuelOptions` | `prices`: list of `FuelPrice` with `type` (`DIESEL`, `REGULAR_UNLEADED`, `PREMIUM`, `LPG`, …), `price` ([`Money`](#money)) and `updateTime` |
| `EvChargeOptions` | `connectorCount`, and `connectors`: list of `EvConnectorGroup` with `type`, `maxChargeRateKw`, `count`, `availableCount`, `outOfServiceCount`, `availabilityUpdateTime` |

### Money

`currencyCode` ("INR") and `amount` (`num`, such as 104.21). Used by `PriceRange` and `FuelPrice`.

### PostalAddress

`regionCode`, `languageCode`, `postalCode`, `administrativeArea` (state), `locality` (city), `sublocality`, `addressLines` (street lines), `organization`.

### PlaceSearchResults

What `searchText` returns: a `List<Place>` you can loop over as usual, plus `nextPageToken` (`String?`) for the next page.

### GeocodingResult

From `reverseGeocode` and `geocode`.

| Field | Type | Example / description |
|---|---|---|
| `formattedAddress` | `String` | "Apollo Bandar, Colaba, Mumbai, Maharashtra 400001, India" |
| `location` | `Coordinates` | Latitude and longitude. |
| `placeId` | `String` | Works with `details` too. |
| `types` | `List<String>` | `['street_address']`, `['locality', 'political']`, … |
| `addressComponents` | `List<AddressComponent>` | Address parts, with the getters below. |
| `locationType` | `LocationType?` | How exact: `rooftop`, `rangeInterpolated`, `geometricCenter`, `approximate`. |
| `viewport` | `Viewport?` | Area to show on a map. |
| `bounds` | `Viewport?` | Whole area, for areas such as a city. |
| `plusCode` | `PlusCode?` | `globalCode` and `compoundCode`. |
| `postcodeLocalities` | `List<String>` | Localities a postal code covers. |
| `partialMatch` | `bool` | Only part of the address matched. |

### AddressComponent and address parts

Each `AddressComponent` has `longText` ("Maharashtra"), `shortText` ("MH"), `types` and `languageCode`. The list has getters for the usual parts:

| Getter | Example |
|---|---|
| `streetNumber`, `street`, `premise` | 10, Shahid Bhagat Singh Rd, Oxford Center |
| `area` | Colaba |
| `city` | Mumbai |
| `district` | Mumbai City |
| `state`, `stateCode` | Maharashtra, MH |
| `postalCode` | 400001 |
| `country`, `countryCode` | India, IN |
| `ofType('neighborhood')` | Any other type |

### Location types

| Class | Description |
|---|---|
| `Coordinates(latitude, longitude)` | A point. `distanceTo(other)` gives meters. |
| `LocationArea.circle(center, radiusMeters)` | A circle, for bias, restriction and nearby search. |
| `LocationArea.rectangle(low, high)` | A rectangle from south-west to north-east. |
| `Viewport` | `low`, `high`, `center`, and `toArea()` to search inside it. |
| `PlusCode` | `globalCode`, `compoundCode`. |
| `PlacesSession` | A session token for autocomplete billing. |

## 🎛️ Choosing fields (PlaceField)

`details`, `searchText`, `searchNearby` and the widgets take `fields`. Google bills a request by its most expensive field, so ask only for what you show.

**Presets**

| Preset | What you get |
|---|---|
| `PlaceField.basic` (default) | ID, name, address, location, types |
| `PlaceField.address` | `basic` + short and postal address, address parts, viewport. For address forms. |
| `PlaceField.details` | Everything a place page shows: type, status, contact, rating, price, current hours, photos, Maps links |
| `PlaceField.all` | Every field in this package, including reviews, summaries and amenities. The most expensive. |

**Or pick fields yourself**, grouped by the tier Google bills them at:

| Tier | Fields |
|---|---|
| Essentials | `id`, `formattedAddress`, `shortAddress`, `adrFormatAddress`, `postalAddress`, `addressComponents`, `addressDescriptor`, `location`, `viewport`, `plusCode`, `types`, `photos`, `timeZone` |
| Pro | `displayName`, `primaryType`, `primaryTypeLabel`, `googleMapsTypeLabel`, `iconMaskBaseUri`, `iconBackgroundColor`, `businessStatus`, `pureServiceAreaBusiness`, `googleMapsUri`, `googleMapsLinks`, `utcOffsetMinutes`, `accessibilityOptions`, `containingPlaces`, `subDestinations` |
| Enterprise | `phoneNumber`, `internationalPhoneNumber`, `websiteUri`, `rating`, `userRatingCount`, `priceLevel`, `priceRange`, `openingHours`, `currentOpeningHours`, `secondaryOpeningHours`, `currentSecondaryOpeningHours` |
| Enterprise + Atmosphere | `editorialSummary`, `generativeSummary`, `reviewSummary`, `reviews`, `parkingOptions`, `paymentOptions`, `fuelOptions`, `evChargeOptions`, and every amenity (`delivery`, `dineIn`, `servesVegetarianFood`, …) |

Check Google Maps Platform pricing for the current prices and free monthly calls of each tier.

```dart
final place = await places.details(id, fields: [
  PlaceField.displayName,
  PlaceField.location,
  PlaceField.rating,
]);
```

Any other field from Google's documentation works with `PlaceField('fieldName')`; its value is in `place.json`.

## ⚠️ Errors

Every method throws a `PlacesException` when a request fails.

| Field | Type | Description |
|---|---|---|
| `code` | `PlacesErrorCode` | What went wrong (below). |
| `message` | `String` | The problem in plain words, ready to show or log. |
| `serverMessage` | `String?` | Google's own message. It often names the project or links to the fix. |
| `statusCode` | `int?` | The HTTP status, if Google answered. |
| `reason` | `String?` | Google's reason, such as `API_KEY_INVALID` or `REQUEST_DENIED`. |

```dart
try {
  await places.details(id);
} on PlacesException catch (e) {
  print('${e.code.name}: ${e.message}');
}
```

| `PlacesErrorCode` | When |
|---|---|
| `invalidApiKey` | The key is wrong or was deleted. |
| `apiNotEnabled` | Places API (New) or Geocoding API isn't enabled in the key's project. |
| `billingNotEnabled` | The project has no billing account. |
| `keyRestricted` | The key's API restrictions or app/website restrictions block the request. A common one: the key doesn't list Geocoding API. |
| `permissionDenied` | Google refused for another reason. |
| `quotaExceeded` | A quota or rate limit was reached. |
| `invalidRequest` | Something in the request is wrong, such as an unknown place type. |
| `notFound` | The place ID is wrong or outdated. |
| `network` | No connection, or Google didn't answer in time. |
| `server` | A temporary problem at Google. Trying again may work. |
| `unknown` | Anything else. |

No results is not an error: searches and geocoding return an empty list.

## 🔐 Keeping the API key safe

An API key inside an app can always be extracted, so limit what it can do:

- **API restrictions:** allow only Places API (New) and Geocoding API.
- **Quotas and budget alerts:** cap the daily requests and get an email if anything is charged.
- **App restrictions:** restrict the key to your Android app (package name + SHA-1), your iOS app (bundle ID) or your website (HTTP referrers). For Android and iOS, pass the same values to the client so it sends them with each request:

```dart
GooglePlaces.initialize(
  apiKey: apiKey,
  androidPackageName: 'com.example.app',
  androidCertFingerprint: 'DA:39:A3:...', // SHA-1 of the signing certificate
  iosBundleId: 'com.example.app',
);
```

Use separate keys per platform if you restrict them differently. Keep the key out of git with `--dart-define` or `--dart-define-from-file`.

## 📜 Google's display rules

Google's terms ask apps to show attribution with Places data:

- **"Google Maps"** next to results shown without a Google map. The widgets add it; in your own UI, use `GoogleMapsAttribution()`.

  You can hide the label for one widget with `showAttribution: false`, or for the whole app with `PlacesKitTheme(showAttribution: false)`. Only do that if your app shows the results on a Google map (which has its own attribution) or credits Google somewhere else on the screen.
- **Photo authors:** `photo.authorAttributions` with each photo.
- **Review authors:** `review.author` with each review.
- **AI summaries:** `disclosureText` with each summary.

See Google's Places API policies for the details.

## 📱 Platforms

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

There's no native code. On Android, the app needs the `INTERNET` permission in `AndroidManifest.xml` (Flutter adds it only to debug builds). On macOS, enable outgoing connections (`com.apple.security.network.client`).

## Example

The [example app](https://github.com/parthbhensdadiya226/google_places_kit/tree/main/example) initializes the client once in `main()` and has three tabs: place search with the autocomplete field, the full-screen page and a fully custom page built on `PlaceAutocompleteController`; nearby and text search with a full place sheet; and coordinates ↔ address. Run it with your key:

```bash
cd example
flutter run --dart-define=PLACES_API_KEY=your-api-key
```

## ☕ Support

If this package saves you time, you can support its maintenance with a coffee:

<a href="https://buymeacoffee.com/parthbhensdadiya"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="48"></a>

Or scan the code:

<img src="https://raw.githubusercontent.com/parthbhensdadiya226/google_places_kit/main/doc/support_qr.png" width="160" alt="QR code for buymeacoffee.com/parthbhensdadiya">

## License

MIT. Google, Google Maps and Google Places are trademarks of Google LLC; this package is not affiliated with or endorsed by Google.
