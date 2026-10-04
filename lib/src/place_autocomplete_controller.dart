import 'package:flutter/foundation.dart';

import 'errors.dart';
import 'google_places.dart';
import 'models.dart';
import 'place_field.dart';

/// Filters for the suggestions in [PlaceAutocompleteController] and the
/// search widgets. See [GooglePlaces.autocomplete].
@immutable
class PlaceAutocompleteOptions {
  /// Creates autocomplete filters.
  const PlaceAutocompleteOptions({
    this.locationBias,
    this.locationRestriction,
    this.types = const [],
    this.countries = const [],
    this.origin,
  });

  /// Prefer places in this area.
  final LocationArea? locationBias;

  /// Only places in this area.
  final LocationArea? locationRestriction;

  /// Up to five place types, such as `['restaurant']` or `['(cities)']`.
  final List<String> types;

  /// Up to 15 countries, such as `['IN']`.
  final List<String> countries;

  /// Show each suggestion's distance from here.
  final Coordinates? origin;
}

/// The search logic of the ready-made widgets, without any UI, so you can
/// build your own.
///
/// It waits until the user pauses typing, uses one [PlacesSession] per
/// search, ignores answers to older searches, and tracks [suggestions],
/// [loading] and [error]. Rebuild your UI when it notifies:
///
/// ```dart
/// final search = PlaceAutocompleteController();
///
/// TextField(onChanged: search.search);
/// ListenableBuilder(
///   listenable: search,
///   builder: (context, _) => Column(
///     children: [
///       for (final s in search.suggestions)
///         ListTile(
///           title: Text(s.mainText),
///           onTap: () async {
///             final place = await search.select(s);
///           },
///         ),
///     ],
///   ),
/// );
/// ```
///
/// Call [dispose] when you're done with it.
class PlaceAutocompleteController extends ChangeNotifier {
  /// Creates a controller. Without [places], it uses
  /// [GooglePlaces.instance].
  PlaceAutocompleteController({
    GooglePlaces? places,
    this.options = const PlaceAutocompleteOptions(),
    this.fields = PlaceField.basic,
    this.debounce = const Duration(milliseconds: 300),
    this.minLength = 2,
    this.onError,
  }) : _places = places;

  final GooglePlaces? _places;

  /// The client that makes the requests: the one passed to the
  /// constructor, or [GooglePlaces.instance].
  GooglePlaces get places => _places ?? GooglePlaces.instance;

  /// Filters for the suggestions. Change it any time, for example when the
  /// user's location is known; the next search uses it.
  PlaceAutocompleteOptions options;

  /// The fields [select] gets for the picked place.
  List<PlaceField> fields;

  /// How long to wait after the last keystroke before asking Google.
  Duration debounce;

  /// Suggestions start after this many characters.
  int minLength;

  /// Called when a request fails, in addition to setting [error].
  ValueChanged<PlacesException>? onError;

  var _session = PlacesSession();
  var _request = 0;
  var _query = '';
  var _suggestions = const <PlaceSuggestion>[];
  var _loading = false;
  PlacesException? _error;
  var _disposed = false;

  /// The text of the latest search, trimmed. Empty after [clear] and after
  /// a place is picked.
  String get query => _query;

  /// The suggestions for [query]. Empty until the user types [minLength]
  /// characters.
  List<PlaceSuggestion> get suggestions => _suggestions;

  /// True from the moment the user types until the suggestions arrive, and
  /// while a picked place is fetched. Use it for a spinner or skeleton.
  bool get loading => _loading;

  /// Why the latest request failed, or null. Cleared by the next answer.
  PlacesException? get error => _error;

  /// Whether Google found nothing for [query]: done loading, no error, and
  /// no suggestions. Use it for a "No places found" message.
  bool get hasNoResults =>
      _query.length >= minLength &&
      !_loading &&
      _error == null &&
      _suggestions.isEmpty;

  /// Searches for [text] once the user pauses typing. Call it on every
  /// keystroke, such as from `TextField.onChanged`.
  ///
  /// Returns the suggestions, or an empty list if a newer search replaced
  /// this one or the request failed. Errors don't throw; they go to [error]
  /// and [onError].
  Future<List<PlaceSuggestion>> search(String text) async {
    final input = text.trim();
    final request = ++_request;
    _query = input;
    if (input.length < minLength) {
      _update(suggestions: const [], loading: false, error: null);
      return const [];
    }
    _update(loading: true);
    await Future<void>.delayed(debounce);
    if (request != _request || _disposed) return const [];
    try {
      final suggestions = await places.autocomplete(
        input,
        session: _session,
        locationBias: options.locationBias,
        locationRestriction: options.locationRestriction,
        types: options.types,
        countries: options.countries,
        origin: options.origin,
      );
      if (request != _request || _disposed) return const [];
      _update(suggestions: suggestions, loading: false, error: null);
      return suggestions;
    } on PlacesException catch (e) {
      if (request == _request && !_disposed) {
        _update(suggestions: const [], loading: false, error: e);
        onError?.call(e);
      }
      return const [];
    }
  }

  /// Gets the full place for [suggestion] with [fields] (or this
  /// controller's [PlaceAutocompleteController.fields]), ends the session,
  /// and clears the query and suggestions.
  ///
  /// Returns null if the request failed; see [error].
  Future<Place?> select(
    PlaceSuggestion suggestion, {
    List<PlaceField>? fields,
  }) async {
    _request++; // a pending search no longer matters
    _update(loading: true);
    try {
      final place = await places.details(
        suggestion.placeId,
        fields: fields ?? this.fields,
        session: _session,
      );
      _query = '';
      _update(suggestions: const [], error: null);
      return place;
    } on PlacesException catch (e) {
      if (!_disposed) {
        _update(error: e);
        onError?.call(e);
      }
      return null;
    } finally {
      _session = PlacesSession();
      _update(loading: false);
    }
  }

  /// Clears the query, suggestions and error, and cancels a pending search.
  void clear() {
    _request++;
    _query = '';
    _update(suggestions: const [], loading: false, error: null);
  }

  // Sentinel so `error: null` can clear the error.
  static const _keep = Object();

  void _update({
    List<PlaceSuggestion>? suggestions,
    bool? loading,
    Object? error = _keep,
  }) {
    if (_disposed) return;
    if (suggestions != null) _suggestions = suggestions;
    if (loading != null) _loading = loading;
    if (!identical(error, _keep)) _error = error as PlacesException?;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
