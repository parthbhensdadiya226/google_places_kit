import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'errors.dart';
import 'google_places.dart';
import 'models.dart';
import 'place_autocomplete_controller.dart';
import 'place_field.dart';
import 'theme.dart';

/// Builds one suggestion. Call [onSelected] when the user picks it.
typedef PlaceSuggestionBuilder =
    Widget Function(
      BuildContext context,
      PlaceSuggestion suggestion,
      VoidCallback onSelected,
    );

/// Builds the whole suggestion list. Call [onSelected] with the suggestion
/// the user picks.
typedef PlaceSuggestionsViewBuilder =
    Widget Function(
      BuildContext context,
      List<PlaceSuggestion> suggestions,
      ValueChanged<PlaceSuggestion> onSelected,
    );

/// Builds the text field of [PlaceAutocompleteField]. Use the given
/// [controller] and [focusNode]; [loading] is true while a request runs.
typedef PlaceFieldViewBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      FocusNode focusNode,
      bool loading,
    );

/// A search field that suggests places in a floating panel while the user
/// types, and gives you the full [Place] when they pick one.
///
/// ```dart
/// PlaceAutocompleteField(
///   fields: PlaceField.address,
///   onSelected: (place) => print(place.formattedAddress),
/// )
/// ```
///
/// It uses [GooglePlaces.instance] unless you pass [places]. Requests wait
/// until the user pauses typing ([debounce]) and share a [PlacesSession],
/// so a whole search is billed as one session. The panel shows a loading
/// skeleton, the suggestions with an icon for each kind of place, "No
/// places found", or the error. Arrow keys, Enter and Escape work on
/// desktop and web.
///
/// Restyle it with [PlacesKitTheme], [decoration] and [style], or replace
/// parts with [fieldBuilder], [suggestionBuilder] and
/// [suggestionsViewBuilder]. For a completely custom UI, use
/// [PlaceAutocompleteController].
class PlaceAutocompleteField extends StatefulWidget {
  /// Creates a place search field.
  const PlaceAutocompleteField({
    super.key,
    this.places,
    required this.onSelected,
    this.fields = PlaceField.basic,
    this.options = const PlaceAutocompleteOptions(),
    this.hintText = 'Search for a place',
    this.decoration,
    this.style,
    this.debounce = const Duration(milliseconds: 300),
    this.minLength = 2,
    this.onError,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.optionsMaxHeight = 380,
    this.fieldBuilder,
    this.suggestionBuilder,
    this.suggestionsViewBuilder,
    this.showAttribution,
  });

  /// The client that makes the requests. Default: [GooglePlaces.instance].
  final GooglePlaces? places;

  /// Called with the picked place, with the [fields] you asked for.
  final ValueChanged<Place> onSelected;

  /// The fields to get for the picked place. See [PlaceField].
  final List<PlaceField> fields;

  /// Filters for the suggestions.
  final PlaceAutocompleteOptions options;

  /// The hint in the default field.
  final String hintText;

  /// Replaces the default rounded, filled look. A clear button or a
  /// spinner replaces its suffix icon while there is text.
  final InputDecoration? decoration;

  /// The style of the typed text.
  final TextStyle? style;

  /// How long to wait after the last keystroke before asking Google.
  final Duration debounce;

  /// Suggestions start after this many characters.
  final int minLength;

  /// Called when a request fails, such as for a wrong API key. The panel
  /// also shows the error.
  final ValueChanged<PlacesException>? onError;

  /// The field's controller, if you want to read or set its text.
  final TextEditingController? controller;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether the field takes focus when it appears.
  final bool autofocus;

  /// Whether the field can be used.
  final bool enabled;

  /// The tallest the suggestion panel gets.
  final double optionsMaxHeight;

  /// Builds your own text field instead of the default one. Use the given
  /// controller and focus node; the search follows the controller's text.
  final PlaceFieldViewBuilder? fieldBuilder;

  /// Builds each suggestion instead of [PlaceSuggestionTile]. The panel,
  /// its states and the attribution stay.
  final PlaceSuggestionBuilder? suggestionBuilder;

  /// Builds the whole panel instead of [PlaceSuggestionsPanel]. Include
  /// [GoogleMapsAttribution] in it.
  final PlaceSuggestionsViewBuilder? suggestionsViewBuilder;

  /// Whether to show the "Google Maps" label under the results. Default:
  /// [PlacesKitTheme.showAttribution], which is true.
  ///
  /// Google requires this attribution when Places results are shown
  /// without a Google map. Turn it off only if your app shows the results
  /// on a Google map, or credits Google another way.
  final bool? showAttribution;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  late final TextEditingController _text =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final _search = PlaceAutocompleteController(
    places: widget.places,
    options: widget.options,
    fields: widget.fields,
    debounce: widget.debounce,
    minLength: widget.minLength,
    onError: (e) => widget.onError?.call(e),
  );
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _fieldKey = GlobalKey();
  late var _lastText = _text.text;
  var _settingText = false;
  var _highlighted = -1;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
    _focusNode.addListener(_syncPanel);
    _search.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(PlaceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _search
      ..options = widget.options
      ..fields = widget.fields
      ..debounce = widget.debounce
      ..minLength = widget.minLength;
  }

  @override
  void dispose() {
    _text.removeListener(_onText);
    _focusNode.removeListener(_syncPanel);
    _search.dispose();
    if (widget.controller == null) _text.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  // Search whenever the text changes, so a custom field needs no wiring.
  void _onText() {
    if (_text.text == _lastText) return; // only the selection moved
    _lastText = _text.text;
    if (!_settingText) _search.search(_text.text);
  }

  void _onSearch() {
    if (_highlighted >= _search.suggestions.length) _highlighted = -1;
    _syncPanel();
  }

  void _syncPanel() {
    final show =
        _focusNode.hasFocus &&
        _search.query.isNotEmpty &&
        _search.query.length >= widget.minLength;
    show ? _portal.show() : _portal.hide();
  }

  void _move(int step) {
    final count = _search.suggestions.length;
    if (count == 0) return;
    if (!_portal.isShowing) _syncPanel();
    setState(() {
      _highlighted = _highlighted < 0
          ? (step > 0 ? 0 : count - 1)
          : (_highlighted + step) % count;
    });
  }

  void _submit() {
    final suggestions = _search.suggestions;
    if (suggestions.isEmpty) return;
    _select(suggestions[_highlighted < 0 ? 0 : _highlighted]);
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    _settingText = true;
    _text.value = TextEditingValue(
      text: suggestion.text,
      selection: TextSelection.collapsed(offset: suggestion.text.length),
    );
    _settingText = false;
    _highlighted = -1;
    _focusNode.unfocus();
    final place = await _search.select(suggestion);
    if (place != null && mounted) widget.onSelected(place);
  }

  Widget _field(BuildContext context) {
    final decoration =
        widget.decoration ?? _searchDecoration(context, widget.hintText);
    return TextField(
      controller: _text,
      focusNode: _focusNode,
      style: widget.style,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      decoration: decoration.copyWith(
        suffixIcon: _SuffixButton(
          // While typing the panel shows progress; the spinner is for
          // fetching the picked place.
          loading: _search.loading && !_focusNode.hasFocus,
          showClear: _text.text.isNotEmpty,
          onClear: _text.clear,
          fallback: decoration.suffixIcon,
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box != null && box.hasSize ? box.size.width : 320.0;
    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: TextFieldTapRegion(
            child: _Appear(
              child: ListenableBuilder(
                listenable: _search,
                builder: (context, _) =>
                    widget.suggestionsViewBuilder?.call(
                      context,
                      _search.suggestions,
                      _select,
                    ) ??
                    PlaceSuggestionsPanel(
                      controller: _search,
                      onSelected: _select,
                      highlightedIndex: _highlighted,
                      suggestionBuilder: widget.suggestionBuilder,
                      maxHeight: widget.optionsMaxHeight,
                      showAttribution: widget.showAttribution,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _panel,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
            const SingleActivator(LogicalKeyboardKey.escape): _portal.hide,
          },
          child: KeyedSubtree(
            key: _fieldKey,
            child: ListenableBuilder(
              listenable: Listenable.merge([_search, _text, _focusNode]),
              builder: (context, _) =>
                  widget.fieldBuilder?.call(
                    context,
                    _text,
                    _focusNode,
                    _search.loading,
                  ) ??
                  _field(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating panel of [PlaceAutocompleteField]: a loading skeleton, the
/// suggestions, "No places found" or the error, with the Google Maps
/// attribution.
///
/// Use it under your own field with a [PlaceAutocompleteController].
class PlaceSuggestionsPanel extends StatelessWidget {
  /// Creates a panel that shows [controller]'s state.
  const PlaceSuggestionsPanel({
    super.key,
    required this.controller,
    required this.onSelected,
    this.highlightedIndex = -1,
    this.suggestionBuilder,
    this.maxHeight = 380,
    this.showAttribution,
  });

  /// The search to show.
  final PlaceAutocompleteController controller;

  /// Called when the user picks a suggestion.
  final ValueChanged<PlaceSuggestion> onSelected;

  /// The suggestion chosen with the arrow keys, or -1.
  final int highlightedIndex;

  /// Builds each suggestion instead of [PlaceSuggestionTile].
  final PlaceSuggestionBuilder? suggestionBuilder;

  /// The tallest the panel gets.
  final double maxHeight;

  /// Whether to show the "Google Maps" label under the results. Default:
  /// [PlacesKitTheme.showAttribution], which is true.
  ///
  /// Google requires this attribution when Places results are shown
  /// without a Google map. Turn it off only if your app shows the results
  /// on a Google map, or credits Google another way.
  final bool? showAttribution;

  @override
  Widget build(BuildContext context) {
    final theme = PlacesKitTheme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final content = _content(context);
        if (content == null) return const SizedBox.shrink();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.panelColor,
            borderRadius: theme.panelBorderRadius,
            border: Border.all(color: theme.panelBorderColor!),
            boxShadow: theme.panelShadows,
          ),
          child: ClipRRect(
            borderRadius: theme.panelBorderRadius!,
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _content(BuildContext context) {
    final suggestions = controller.suggestions;
    if (controller.error case final error?) {
      return _StatusMessage(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load places",
        subtitle: error.message,
      );
    }
    if (suggestions.isEmpty && controller.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlaceSuggestionSkeleton(),
            PlaceSuggestionSkeleton(),
            PlaceSuggestionSkeleton(),
          ],
        ),
      );
    }
    if (controller.hasNoResults) {
      return _StatusMessage(
        icon: Icons.search_off_rounded,
        title: 'No places found',
        subtitle:
            'Nothing matches "${controller.query}". Check the spelling '
            'or try a nearby area.',
      );
    }
    if (suggestions.isEmpty) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressLine(visible: controller.loading),
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4),
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, i) {
              final suggestion = suggestions[i];
              return _Stagger(
                key: ValueKey(suggestion.placeId),
                index: i,
                child:
                    suggestionBuilder?.call(
                      context,
                      suggestion,
                      () => onSelected(suggestion),
                    ) ??
                    PlaceSuggestionTile(
                      suggestion: suggestion,
                      highlighted: i == highlightedIndex,
                      onTap: () => onSelected(suggestion),
                    ),
              );
            },
          ),
        ),
        if (showAttribution ?? PlacesKitTheme.of(context).showAttribution!)
          const GoogleMapsAttribution(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }
}

/// Opens a full-screen place search and returns the picked place, or null
/// if the user goes back.
///
/// ```dart
/// final place = await showPlaceSearch(context);
/// ```
///
/// It uses [GooglePlaces.instance] unless you pass [places].
Future<Place?> showPlaceSearch(
  BuildContext context, {
  GooglePlaces? places,
  List<PlaceField> fields = PlaceField.basic,
  PlaceAutocompleteOptions options = const PlaceAutocompleteOptions(),
  String hintText = 'Search for a place',
  PlaceSuggestionBuilder? suggestionBuilder,
  Widget Function(BuildContext context, PlacesException error)? errorBuilder,
  WidgetBuilder? emptyBuilder,
  bool? showAttribution,
}) => Navigator.of(context).push<Place>(
  MaterialPageRoute(
    builder: (_) => PlaceSearchPage(
      places: places,
      fields: fields,
      options: options,
      hintText: hintText,
      suggestionBuilder: suggestionBuilder,
      errorBuilder: errorBuilder,
      emptyBuilder: emptyBuilder,
      showAttribution: showAttribution,
    ),
  ),
);

/// A full-screen place search. It pops with the picked [Place]. Usually
/// opened with [showPlaceSearch].
class PlaceSearchPage extends StatefulWidget {
  /// Creates a place search page.
  const PlaceSearchPage({
    super.key,
    this.places,
    this.fields = PlaceField.basic,
    this.options = const PlaceAutocompleteOptions(),
    this.hintText = 'Search for a place',
    this.debounce = const Duration(milliseconds: 300),
    this.minLength = 2,
    this.suggestionBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.showAttribution,
  });

  /// The client that makes the requests. Default: [GooglePlaces.instance].
  final GooglePlaces? places;

  /// The fields to get for the picked place.
  final List<PlaceField> fields;

  /// Filters for the suggestions.
  final PlaceAutocompleteOptions options;

  /// The search field's hint.
  final String hintText;

  /// How long to wait after the last keystroke before asking Google.
  final Duration debounce;

  /// Suggestions start after this many characters.
  final int minLength;

  /// Builds each suggestion instead of [PlaceSuggestionTile].
  final PlaceSuggestionBuilder? suggestionBuilder;

  /// Builds the message for a failed request.
  final Widget Function(BuildContext context, PlacesException error)?
  errorBuilder;

  /// Shown before the user types, such as recent searches. By default a
  /// short invitation to search.
  final WidgetBuilder? emptyBuilder;

  /// Whether to show the "Google Maps" label under the results. Default:
  /// [PlacesKitTheme.showAttribution], which is true.
  ///
  /// Google requires this attribution when Places results are shown
  /// without a Google map. Turn it off only if your app shows the results
  /// on a Google map, or credits Google another way.
  final bool? showAttribution;

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _text = TextEditingController();
  late final _search = PlaceAutocompleteController(
    places: widget.places,
    options: widget.options,
    fields: widget.fields,
    debounce: widget.debounce,
    minLength: widget.minLength,
  );
  var _picking = false;

  @override
  void dispose() {
    _search.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    setState(() => _picking = true);
    final place = await _search.select(suggestion);
    if (!mounted) return;
    if (place != null) {
      Navigator.of(context).pop(place);
    } else {
      setState(() => _picking = false);
    }
  }

  void _submit() {
    if (_search.suggestions.isNotEmpty) _select(_search.suggestions.first);
  }

  Widget _body(BuildContext context) {
    final suggestions = _search.suggestions;
    if (_search.error case final error?) {
      return KeyedSubtree(
        key: const ValueKey('error'),
        child:
            widget.errorBuilder?.call(context, error) ??
            _StatusMessage(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load places",
              subtitle: error.message,
              large: true,
            ),
      );
    }
    if (_search.query.length < widget.minLength && suggestions.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('empty'),
        child:
            widget.emptyBuilder?.call(context) ??
            const _StatusMessage(
              icon: Icons.travel_explore_rounded,
              title: 'Find a place',
              subtitle: 'Search by name, address or business.',
              large: true,
            ),
      );
    }
    if (suggestions.isEmpty && _search.loading) {
      return ListView(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [for (var i = 0; i < 6; i++) const PlaceSuggestionSkeleton()],
      );
    }
    if (_search.hasNoResults) {
      return _StatusMessage(
        key: const ValueKey('none'),
        icon: Icons.search_off_rounded,
        title: 'No places found',
        subtitle:
            'Nothing matches "${_search.query}". Check the spelling '
            'or try a nearby area.',
        large: true,
      );
    }
    final attribution =
        widget.showAttribution ?? PlacesKitTheme.of(context).showAttribution!;
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length + (attribution ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == suggestions.length) return const GoogleMapsAttribution();
        final suggestion = suggestions[i];
        return _Stagger(
          key: ValueKey(suggestion.placeId),
          index: i,
          child:
              widget.suggestionBuilder?.call(
                context,
                suggestion,
                () => _select(suggestion),
              ) ??
              PlaceSuggestionTile(
                suggestion: suggestion,
                onTap: () => _select(suggestion),
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: Listenable.merge([_search, _text]),
              builder: (context, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: _search.search,
                            onSubmitted: (_) => _submit(),
                            decoration:
                                _searchDecoration(
                                  context,
                                  widget.hintText,
                                ).copyWith(
                                  suffixIcon: _SuffixButton(
                                    loading: _picking,
                                    showClear: _text.text.isNotEmpty,
                                    onClear: () {
                                      _text.clear();
                                      _search.clear();
                                    },
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProgressLine(
                    visible: _search.loading && _search.suggestions.isNotEmpty,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _body(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A suggestion row: an icon for the kind of place, the name with the
/// typed part highlighted, the address below, and the distance if known.
class PlaceSuggestionTile extends StatelessWidget {
  /// Creates a suggestion row.
  const PlaceSuggestionTile({
    super.key,
    required this.suggestion,
    required this.onTap,
    this.highlighted = false,
    this.leading,
    this.showIcon = true,
    this.trailing,
    this.showDistance = true,
    this.titleStyle,
    this.matchStyle,
    this.subtitleStyle,
  });

  /// The suggestion to show.
  final PlaceSuggestion suggestion;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Whether the row is chosen with the arrow keys.
  final bool highlighted;

  /// Shown before the text instead of the [PlaceTypeIcon].
  final Widget? leading;

  /// Whether to show [leading] or the place-type icon.
  final bool showIcon;

  /// Shown after the text, instead of the distance.
  final Widget? trailing;

  /// Whether to show the distance, when the suggestion has one.
  final bool showDistance;

  /// Merged into the theme's style for the place name.
  final TextStyle? titleStyle;

  /// Merged into the style of the typed part of the name.
  final TextStyle? matchStyle;

  /// Merged into the theme's style for the address.
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = PlacesKitTheme.of(context);
    final distance = suggestion.distanceMeters;
    final end =
        trailing ??
        (showDistance && distance != null
            ? _DistancePill(meters: distance)
            : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: highlighted ? theme.highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                if (showIcon) ...[
                  leading ?? PlaceTypeIcon(types: suggestion.types),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        highlightMatches(
                          suggestion.mainText,
                          suggestion.mainTextMatches,
                          style: theme.titleStyle?.merge(titleStyle),
                          matchStyle: TextStyle(
                            color: theme.matchColor,
                            fontWeight: FontWeight.w700,
                          ).merge(matchStyle),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (suggestion.secondaryText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          suggestion.secondaryText,
                          style: theme.subtitleStyle?.merge(subtitleStyle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (end != null) ...[const SizedBox(width: 8), end],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded, tinted icon for the kind of place in [types], such as a fork
/// and knife for restaurants or a plane for airports. See [placeTypeIcon].
class PlaceTypeIcon extends StatelessWidget {
  /// Creates an icon for [types].
  const PlaceTypeIcon({super.key, required this.types, this.size = 40});

  /// The place types, such as [PlaceSuggestion.types] or [Place.types].
  final List<String> types;

  /// The width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = PlacesKitTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.iconBackgroundColor,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        placeTypeIcon(types),
        size: size * 0.5,
        color: theme.iconColor,
      ),
    );
  }
}

/// The icon for the first type in [types] that has one, or a map pin.
IconData placeTypeIcon(List<String> types) {
  for (final type in types) {
    if (_typeIcons[type] case final icon?) return icon;
  }
  return Icons.place_rounded;
}

const _typeIcons = <String, IconData>{
  'airport': Icons.flight_rounded,
  'train_station': Icons.train_rounded,
  'subway_station': Icons.subway_rounded,
  'light_rail_station': Icons.tram_rounded,
  'bus_station': Icons.directions_bus_rounded,
  'bus_stop': Icons.directions_bus_rounded,
  'transit_station': Icons.directions_transit_rounded,
  'restaurant': Icons.restaurant_rounded,
  'food': Icons.restaurant_rounded,
  'meal_takeaway': Icons.takeout_dining_rounded,
  'meal_delivery': Icons.delivery_dining_rounded,
  'cafe': Icons.local_cafe_rounded,
  'coffee_shop': Icons.local_cafe_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'bar': Icons.local_bar_rounded,
  'night_club': Icons.nightlife_rounded,
  'lodging': Icons.hotel_rounded,
  'hotel': Icons.hotel_rounded,
  'hospital': Icons.local_hospital_rounded,
  'doctor': Icons.medical_services_rounded,
  'pharmacy': Icons.local_pharmacy_rounded,
  'drugstore': Icons.local_pharmacy_rounded,
  'school': Icons.school_rounded,
  'primary_school': Icons.school_rounded,
  'secondary_school': Icons.school_rounded,
  'university': Icons.school_rounded,
  'shopping_mall': Icons.local_mall_rounded,
  'supermarket': Icons.local_grocery_store_rounded,
  'grocery_store': Icons.local_grocery_store_rounded,
  'clothing_store': Icons.checkroom_rounded,
  'store': Icons.storefront_rounded,
  'park': Icons.park_rounded,
  'beach': Icons.beach_access_rounded,
  'zoo': Icons.pets_rounded,
  'museum': Icons.museum_rounded,
  'art_gallery': Icons.palette_rounded,
  'historical_landmark': Icons.fort_rounded,
  'tourist_attraction': Icons.photo_camera_rounded,
  'stadium': Icons.stadium_rounded,
  'gym': Icons.fitness_center_rounded,
  'movie_theater': Icons.movie_rounded,
  'gas_station': Icons.local_gas_station_rounded,
  'electric_vehicle_charging_station': Icons.ev_station_rounded,
  'parking': Icons.local_parking_rounded,
  'car_repair': Icons.car_repair_rounded,
  'atm': Icons.local_atm_rounded,
  'bank': Icons.account_balance_rounded,
  'hindu_temple': Icons.temple_hindu_rounded,
  'mosque': Icons.mosque_rounded,
  'church': Icons.church_rounded,
  'synagogue': Icons.synagogue_rounded,
  'place_of_worship': Icons.temple_buddhist_rounded,
  'police': Icons.local_police_rounded,
  'post_office': Icons.local_post_office_rounded,
  'city_hall': Icons.account_balance_rounded,
  'natural_feature': Icons.landscape_rounded,
  'country': Icons.public_rounded,
  'administrative_area_level_1': Icons.map_rounded,
  'locality': Icons.location_city_rounded,
  'sublocality': Icons.holiday_village_rounded,
  'neighborhood': Icons.holiday_village_rounded,
  'postal_code': Icons.markunread_mailbox_rounded,
  'route': Icons.add_road_rounded,
  'street_address': Icons.home_rounded,
  'premise': Icons.apartment_rounded,
  'subpremise': Icons.apartment_rounded,
};

/// A shimmering placeholder shaped like a [PlaceSuggestionTile], shown
/// while suggestions load.
class PlaceSuggestionSkeleton extends StatefulWidget {
  /// Creates a placeholder row.
  const PlaceSuggestionSkeleton({super.key});

  @override
  State<PlaceSuggestionSkeleton> createState() =>
      _PlaceSuggestionSkeletonState();
}

class _PlaceSuggestionSkeletonState extends State<PlaceSuggestionSkeleton>
    with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;
    final shine = Color.lerp(base, colors.surface, 0.55)!;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, shine, base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(_shimmer.value),
          ).createShader(bounds),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 18, 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(0.55, 12),
                    const SizedBox(height: 8),
                    bar(0.85, 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// [text] with the [matches] in [matchStyle] (bold by default), the way
/// Google shows suggestions. Without matches, all of [text] is semi-bold.
TextSpan highlightMatches(
  String text,
  List<TextMatch> matches, {
  TextStyle? style,
  TextStyle? matchStyle,
}) {
  final match = matchStyle ?? const TextStyle(fontWeight: FontWeight.w700);
  if (matches.isEmpty) {
    return TextSpan(
      text: text,
      style: style ?? const TextStyle(fontWeight: FontWeight.w600),
    );
  }
  final spans = <TextSpan>[];
  var position = 0;
  for (final m in matches) {
    final start = m.start.clamp(position, text.length);
    final end = m.end.clamp(start, text.length);
    if (start > position) {
      spans.add(TextSpan(text: text.substring(position, start)));
    }
    spans.add(TextSpan(text: text.substring(start, end), style: match));
    position = end;
  }
  if (position < text.length) {
    spans.add(TextSpan(text: text.substring(position)));
  }
  return TextSpan(style: style, children: spans);
}

/// Formats meters as "850 m" or "12.4 km".
String formatDistance(num meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';

/// The "Google Maps" attribution Google requires next to Places results
/// shown without a Google map. The widgets in this package add it for you;
/// use it when you show results in your own UI.
class GoogleMapsAttribution extends StatelessWidget {
  /// Creates the attribution.
  const GoogleMapsAttribution({
    super.key,
    this.style,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 10),
    this.alignment = AlignmentDirectional.centerEnd,
  });

  /// The text style. By default the theme's small label in a muted color.
  final TextStyle? style;

  /// Space around the text.
  final EdgeInsetsGeometry padding;

  /// Where the text sits.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Align(
        alignment: alignment,
        child: Text(
          'Google Maps',
          style:
              style ??
              theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }
}

/// The default search field look: filled, rounded, with a search icon.
InputDecoration _searchDecoration(BuildContext context, String hintText) {
  final theme = PlacesKitTheme.of(context);
  final colors = Theme.of(context).colorScheme;
  final radius = theme.fieldBorderRadius!;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    filled: true,
    fillColor: theme.fieldColor,
    prefixIcon: Icon(Icons.search_rounded, color: colors.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.fieldFocusColor!, width: 1.5),
    ),
  );
}

/// The field's suffix: a spinner, a clear button, or [fallback].
class _SuffixButton extends StatelessWidget {
  const _SuffixButton({
    required this.loading,
    required this.showClear,
    required this.onClear,
    this.fallback,
  });

  final bool loading;
  final bool showClear;
  final VoidCallback onClear;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: loading
          ? const Padding(
              key: ValueKey('loading'),
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : showClear
          ? IconButton(
              key: const ValueKey('clear'),
              tooltip: 'Clear',
              onPressed: onClear,
              icon: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('none'),
              child: fallback ?? const SizedBox.shrink(),
            ),
    );
  }
}

/// A thin progress bar that keeps its height, so content doesn't jump.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: visible
          ? const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            )
          : null,
    ),
  );
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.meters});

  final num meters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        formatDistance(meters),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// An icon in a soft circle with a title and a line of explanation.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: large ? 48 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 72 : 48,
            height: large ? 72 : 48,
            decoration: BoxDecoration(
              color: large
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: large ? 34 : 24,
              color: large
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: large ? 16 : 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (large
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return large
        ? Align(alignment: const Alignment(0, -0.4), child: content)
        : content;
  }
}

/// Fades and slides the panel in when it opens.
class _Appear extends StatelessWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * -8),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Fades and lifts a row in, a little later for each [index].
class _Stagger extends StatelessWidget {
  const _Stagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = 35.0 * index.clamp(0, 8);
    final total = 220 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total.round()),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
