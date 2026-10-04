## 0.1.0

- `GooglePlaces` client for Places API (New) and the Geocoding API, in pure Dart: works on Android, iOS, web and desktop.
- `autocomplete` with session tokens, location bias or restriction, place types, countries and distance from an origin.
- `details` with field masks (`PlaceField`, with `basic`, `address`, `details` and `all` presets), so requests ask only for what they show.
- `searchText` (with paging through `nextPageToken`) and `searchNearby`, with type, rating and open-now filters and ranking by distance.
- `photoUrl` returns a key-free image URL; photo and review author attributions are included.
- Typed models for every response: `Place` with opening hours and periods, photos, reviews, AI summaries, amenities, accessibility, parking, payment, fuel prices, EV chargers, landmarks, postal address, Google Maps links and more; `PlaceSuggestion` with match offsets; `GeocodingResult` with location type, viewport and plus code.
- `reverseGeocode` (coordinates to address) and `geocode` (address to coordinates).
- `AddressParts` getters on address components: `street`, `area`, `city`, `district`, `state`, `postalCode`, `country`, `countryCode` and more.
- `PlacesException` with a `PlacesErrorCode` for a wrong key, a disabled API, missing billing, key restrictions, quotas, bad requests, network and server errors, plus Google's own message.
- `GooglePlaces.initialize()` once in `main()`, then `GooglePlaces.instance` anywhere; the widgets and controller use it when no client is passed.
- Modern widgets: `PlaceAutocompleteField` (rounded field, floating panel with place-type icons, highlighted matches, loading skeleton, no-results and error states, animations, arrow keys and Enter), `showPlaceSearch` / `PlaceSearchPage`, `PlaceSuggestionsPanel`, `PlaceSuggestionTile`, `PlaceSuggestionSkeleton`, `PlaceTypeIcon` and `GoogleMapsAttribution`, with builders for the field, each suggestion and the whole panel.
- `PlacesKitTheme` to restyle every widget from `ThemeData`; defaults follow the app's color scheme in light and dark mode.
- `showAttribution` on each widget and in `PlacesKitTheme`, for apps that show results on a Google map or credit Google elsewhere. On by default.
- `PlaceAutocompleteController`: the widgets' search logic (debouncing, sessions, loading and error state) without UI, for your own design.
- Headers for keys restricted to an Android app (package name and SHA-1) or an iOS app (bundle ID).
