import 'package:flutter/material.dart';

/// Colors, shapes and text styles for the widgets in this package.
///
/// Every value is optional; the rest come from the app's [ColorScheme], so
/// the widgets match light and dark themes without any setup. Add it to
/// your theme to change all the widgets at once:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     colorSchemeSeed: Colors.teal,
///     extensions: const [
///       PlacesKitTheme(
///         fieldBorderRadius: BorderRadius.all(Radius.circular(12)),
///         panelBorderRadius: BorderRadius.all(Radius.circular(12)),
///       ),
///     ],
///   ),
/// )
/// ```
@immutable
class PlacesKitTheme extends ThemeExtension<PlacesKitTheme> {
  /// Creates a theme. Leave out what you don't want to change.
  const PlacesKitTheme({
    this.fieldColor,
    this.fieldBorderRadius,
    this.fieldFocusColor,
    this.panelColor,
    this.panelBorderColor,
    this.panelBorderRadius,
    this.panelShadows,
    this.iconBackgroundColor,
    this.iconColor,
    this.matchColor,
    this.highlightColor,
    this.titleStyle,
    this.subtitleStyle,
    this.showAttribution,
  });

  /// The search field's background. Default: `surfaceContainerHigh`.
  final Color? fieldColor;

  /// The search field's corners. Default: fully rounded.
  final BorderRadius? fieldBorderRadius;

  /// The search field's outline while focused. Default: `primary`.
  final Color? fieldFocusColor;

  /// The suggestion panel's background. Default: `surfaceContainerLow`.
  final Color? panelColor;

  /// The suggestion panel's thin outline. Default: a faint
  /// `outlineVariant`.
  final Color? panelBorderColor;

  /// The suggestion panel's corners. Default: 20.
  final BorderRadius? panelBorderRadius;

  /// The suggestion panel's shadow. Default: a soft, wide shadow.
  final List<BoxShadow>? panelShadows;

  /// The background of the place-type icon. Default: `primaryContainer`.
  final Color? iconBackgroundColor;

  /// The place-type icon. Default: `onPrimaryContainer`.
  final Color? iconColor;

  /// The typed part of a suggestion. Default: `primary`.
  final Color? matchColor;

  /// The suggestion chosen with the arrow keys. Default: a light `primary`
  /// tint.
  final Color? highlightColor;

  /// A suggestion's name.
  final TextStyle? titleStyle;

  /// A suggestion's address.
  final TextStyle? subtitleStyle;

  /// Whether the widgets show the "Google Maps" label under results.
  /// Default: true.
  ///
  /// Google requires this attribution when Places results are shown
  /// without a Google map. Turn it off only if your app shows the results
  /// on a Google map, or credits Google another way.
  final bool? showAttribution;

  /// The theme for [context]: the app's [PlacesKitTheme], with every value
  /// it leaves out filled in from the [ColorScheme].
  static PlacesKitTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final defaults = PlacesKitTheme(
      fieldColor: colors.surfaceContainerHigh,
      fieldBorderRadius: const BorderRadius.all(Radius.circular(28)),
      fieldFocusColor: colors.primary,
      panelColor: colors.surfaceContainerLow,
      panelBorderColor: colors.outlineVariant.withValues(alpha: 0.5),
      panelBorderRadius: const BorderRadius.all(Radius.circular(20)),
      panelShadows: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.14),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
      iconBackgroundColor: colors.primaryContainer,
      iconColor: colors.onPrimaryContainer,
      matchColor: colors.primary,
      highlightColor: colors.primary.withValues(alpha: 0.08),
      titleStyle: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
      subtitleStyle: theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.3,
      ),
      showAttribution: true,
    );
    final own = theme.extension<PlacesKitTheme>();
    return own == null ? defaults : defaults._with(own);
  }

  PlacesKitTheme _with(PlacesKitTheme other) => copyWith(
    fieldColor: other.fieldColor,
    fieldBorderRadius: other.fieldBorderRadius,
    fieldFocusColor: other.fieldFocusColor,
    panelColor: other.panelColor,
    panelBorderColor: other.panelBorderColor,
    panelBorderRadius: other.panelBorderRadius,
    panelShadows: other.panelShadows,
    iconBackgroundColor: other.iconBackgroundColor,
    iconColor: other.iconColor,
    matchColor: other.matchColor,
    highlightColor: other.highlightColor,
    titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
    subtitleStyle:
        subtitleStyle?.merge(other.subtitleStyle) ?? other.subtitleStyle,
    showAttribution: other.showAttribution,
  );

  @override
  PlacesKitTheme copyWith({
    Color? fieldColor,
    BorderRadius? fieldBorderRadius,
    Color? fieldFocusColor,
    Color? panelColor,
    Color? panelBorderColor,
    BorderRadius? panelBorderRadius,
    List<BoxShadow>? panelShadows,
    Color? iconBackgroundColor,
    Color? iconColor,
    Color? matchColor,
    Color? highlightColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    bool? showAttribution,
  }) => PlacesKitTheme(
    fieldColor: fieldColor ?? this.fieldColor,
    fieldBorderRadius: fieldBorderRadius ?? this.fieldBorderRadius,
    fieldFocusColor: fieldFocusColor ?? this.fieldFocusColor,
    panelColor: panelColor ?? this.panelColor,
    panelBorderColor: panelBorderColor ?? this.panelBorderColor,
    panelBorderRadius: panelBorderRadius ?? this.panelBorderRadius,
    panelShadows: panelShadows ?? this.panelShadows,
    iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
    iconColor: iconColor ?? this.iconColor,
    matchColor: matchColor ?? this.matchColor,
    highlightColor: highlightColor ?? this.highlightColor,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    showAttribution: showAttribution ?? this.showAttribution,
  );

  @override
  PlacesKitTheme lerp(PlacesKitTheme? other, double t) {
    if (other == null) return this;
    return PlacesKitTheme(
      fieldColor: Color.lerp(fieldColor, other.fieldColor, t),
      fieldBorderRadius: BorderRadius.lerp(
        fieldBorderRadius,
        other.fieldBorderRadius,
        t,
      ),
      fieldFocusColor: Color.lerp(fieldFocusColor, other.fieldFocusColor, t),
      panelColor: Color.lerp(panelColor, other.panelColor, t),
      panelBorderColor: Color.lerp(panelBorderColor, other.panelBorderColor, t),
      panelBorderRadius: BorderRadius.lerp(
        panelBorderRadius,
        other.panelBorderRadius,
        t,
      ),
      panelShadows: BoxShadow.lerpList(panelShadows, other.panelShadows, t),
      iconBackgroundColor: Color.lerp(
        iconBackgroundColor,
        other.iconBackgroundColor,
        t,
      ),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      matchColor: Color.lerp(matchColor, other.matchColor, t),
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      showAttribution: t < 0.5 ? showAttribution : other.showAttribution,
    );
  }
}
