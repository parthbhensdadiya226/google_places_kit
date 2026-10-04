/// A field to ask for in [GooglePlaces.details], [GooglePlaces.searchText]
/// and [GooglePlaces.searchNearby].
///
/// Google bills each request by the most expensive field in it, so ask only
/// for what you show. The fields are grouped below by the tier they are
/// billed at (Essentials, Pro, Enterprise, Enterprise + Atmosphere); see
/// Google Maps Platform pricing for the current prices and the free monthly
/// calls of each tier.
///
/// ```dart
/// final place = await places.details(id, fields: [
///   PlaceField.displayName,
///   PlaceField.formattedAddress,
///   PlaceField.location,
/// ]);
/// ```
final class PlaceField {
  /// Any field from Google's documentation. Its raw value is in
  /// [Place.json].
  const PlaceField(this.value);

  /// The field name the API uses.
  final String value;

  // Essentials ---------------------------------------------------------------

  /// [Place.id].
  static const id = PlaceField('id');

  /// [Place.formattedAddress].
  static const formattedAddress = PlaceField('formattedAddress');

  /// [Place.shortAddress].
  static const shortAddress = PlaceField('shortFormattedAddress');

  /// [Place.adrFormatAddress].
  static const adrFormatAddress = PlaceField('adrFormatAddress');

  /// [Place.postalAddress].
  static const postalAddress = PlaceField('postalAddress');

  /// [Place.addressComponents].
  static const addressComponents = PlaceField('addressComponents');

  /// [Place.addressDescriptor].
  static const addressDescriptor = PlaceField('addressDescriptor');

  /// [Place.location].
  static const location = PlaceField('location');

  /// [Place.viewport].
  static const viewport = PlaceField('viewport');

  /// [Place.plusCode].
  static const plusCode = PlaceField('plusCode');

  /// [Place.types].
  static const types = PlaceField('types');

  /// [Place.photos].
  static const photos = PlaceField('photos');

  /// [Place.timeZone].
  static const timeZone = PlaceField('timeZone');

  // Pro ----------------------------------------------------------------------

  /// [Place.name].
  static const displayName = PlaceField('displayName');

  /// [Place.primaryType].
  static const primaryType = PlaceField('primaryType');

  /// [Place.primaryTypeLabel].
  static const primaryTypeLabel = PlaceField('primaryTypeDisplayName');

  /// [Place.googleMapsTypeLabel].
  static const googleMapsTypeLabel = PlaceField('googleMapsTypeLabel');

  /// [Place.iconMaskBaseUri].
  static const iconMaskBaseUri = PlaceField('iconMaskBaseUri');

  /// [Place.iconBackgroundColor].
  static const iconBackgroundColor = PlaceField('iconBackgroundColor');

  /// [Place.businessStatus].
  static const businessStatus = PlaceField('businessStatus');

  /// [Place.pureServiceAreaBusiness].
  static const pureServiceAreaBusiness = PlaceField('pureServiceAreaBusiness');

  /// [Place.googleMapsUri].
  static const googleMapsUri = PlaceField('googleMapsUri');

  /// [Place.googleMapsLinks].
  static const googleMapsLinks = PlaceField('googleMapsLinks');

  /// [Place.utcOffsetMinutes].
  static const utcOffsetMinutes = PlaceField('utcOffsetMinutes');

  /// [Place.accessibility].
  static const accessibilityOptions = PlaceField('accessibilityOptions');

  /// [Place.containingPlaceIds].
  static const containingPlaces = PlaceField('containingPlaces');

  /// [Place.subDestinationIds].
  static const subDestinations = PlaceField('subDestinations');

  // Enterprise ---------------------------------------------------------------

  /// [Place.phoneNumber].
  static const phoneNumber = PlaceField('nationalPhoneNumber');

  /// [Place.internationalPhoneNumber].
  static const internationalPhoneNumber = PlaceField(
    'internationalPhoneNumber',
  );

  /// [Place.websiteUri].
  static const websiteUri = PlaceField('websiteUri');

  /// [Place.rating].
  static const rating = PlaceField('rating');

  /// [Place.userRatingCount].
  static const userRatingCount = PlaceField('userRatingCount');

  /// [Place.priceLevel].
  static const priceLevel = PlaceField('priceLevel');

  /// [Place.priceRange].
  static const priceRange = PlaceField('priceRange');

  /// [Place.openingHours].
  static const openingHours = PlaceField('regularOpeningHours');

  /// [Place.currentOpeningHours] and [Place.openNow].
  static const currentOpeningHours = PlaceField('currentOpeningHours');

  /// [Place.secondaryOpeningHours].
  static const secondaryOpeningHours = PlaceField(
    'regularSecondaryOpeningHours',
  );

  /// [Place.currentSecondaryOpeningHours].
  static const currentSecondaryOpeningHours = PlaceField(
    'currentSecondaryOpeningHours',
  );

  // Enterprise + Atmosphere --------------------------------------------------

  /// [Place.editorialSummary].
  static const editorialSummary = PlaceField('editorialSummary');

  /// [Place.generativeSummary].
  static const generativeSummary = PlaceField('generativeSummary');

  /// [Place.reviewSummary].
  static const reviewSummary = PlaceField('reviewSummary');

  /// [Place.reviews].
  static const reviews = PlaceField('reviews');

  /// [Place.parking].
  static const parkingOptions = PlaceField('parkingOptions');

  /// [Place.payment].
  static const paymentOptions = PlaceField('paymentOptions');

  /// [Place.fuelOptions].
  static const fuelOptions = PlaceField('fuelOptions');

  /// [Place.evChargeOptions].
  static const evChargeOptions = PlaceField('evChargeOptions');

  /// [PlaceAmenities.delivery].
  static const delivery = PlaceField('delivery');

  /// [PlaceAmenities.dineIn].
  static const dineIn = PlaceField('dineIn');

  /// [PlaceAmenities.takeout].
  static const takeout = PlaceField('takeout');

  /// [PlaceAmenities.curbsidePickup].
  static const curbsidePickup = PlaceField('curbsidePickup');

  /// [PlaceAmenities.reservable].
  static const reservable = PlaceField('reservable');

  /// [PlaceAmenities.servesBreakfast].
  static const servesBreakfast = PlaceField('servesBreakfast');

  /// [PlaceAmenities.servesBrunch].
  static const servesBrunch = PlaceField('servesBrunch');

  /// [PlaceAmenities.servesLunch].
  static const servesLunch = PlaceField('servesLunch');

  /// [PlaceAmenities.servesDinner].
  static const servesDinner = PlaceField('servesDinner');

  /// [PlaceAmenities.servesVegetarianFood].
  static const servesVegetarianFood = PlaceField('servesVegetarianFood');

  /// [PlaceAmenities.servesDessert].
  static const servesDessert = PlaceField('servesDessert');

  /// [PlaceAmenities.servesCoffee].
  static const servesCoffee = PlaceField('servesCoffee');

  /// [PlaceAmenities.servesBeer].
  static const servesBeer = PlaceField('servesBeer');

  /// [PlaceAmenities.servesWine].
  static const servesWine = PlaceField('servesWine');

  /// [PlaceAmenities.servesCocktails].
  static const servesCocktails = PlaceField('servesCocktails');

  /// [PlaceAmenities.outdoorSeating].
  static const outdoorSeating = PlaceField('outdoorSeating');

  /// [PlaceAmenities.liveMusic].
  static const liveMusic = PlaceField('liveMusic');

  /// [PlaceAmenities.menuForChildren].
  static const menuForChildren = PlaceField('menuForChildren');

  /// [PlaceAmenities.goodForChildren].
  static const goodForChildren = PlaceField('goodForChildren');

  /// [PlaceAmenities.goodForGroups].
  static const goodForGroups = PlaceField('goodForGroups');

  /// [PlaceAmenities.goodForWatchingSports].
  static const goodForWatchingSports = PlaceField('goodForWatchingSports');

  /// [PlaceAmenities.allowsDogs].
  static const allowsDogs = PlaceField('allowsDogs');

  /// [PlaceAmenities.restroom].
  static const restroom = PlaceField('restroom');

  // Presets ------------------------------------------------------------------

  /// The ID, name, address, location and types: enough to show a place and
  /// put it on a map. The default.
  static const List<PlaceField> basic = [
    id,
    displayName,
    formattedAddress,
    location,
    types,
  ];

  /// [basic] plus the address parts, the short and postal address and the
  /// viewport, for filling in an address form.
  static const List<PlaceField> address = [
    id,
    displayName,
    formattedAddress,
    shortAddress,
    postalAddress,
    addressComponents,
    location,
    viewport,
    types,
  ];

  /// Everything a place page usually shows: name, address, type, contact,
  /// rating, price, opening hours, photos and the Google Maps links.
  static const List<PlaceField> details = [
    id,
    displayName,
    formattedAddress,
    addressComponents,
    location,
    viewport,
    types,
    primaryTypeLabel,
    businessStatus,
    googleMapsUri,
    googleMapsLinks,
    phoneNumber,
    internationalPhoneNumber,
    websiteUri,
    rating,
    userRatingCount,
    priceLevel,
    priceRange,
    currentOpeningHours,
    photos,
  ];

  /// [details] plus the summaries, reviews, amenities, parking, payment,
  /// accessibility, fuel and EV charging: everything this package reads.
  /// The most expensive tier.
  static const List<PlaceField> all = [
    ...details,
    shortAddress,
    postalAddress,
    addressDescriptor,
    plusCode,
    timeZone,
    utcOffsetMinutes,
    primaryType,
    googleMapsTypeLabel,
    iconMaskBaseUri,
    iconBackgroundColor,
    pureServiceAreaBusiness,
    accessibilityOptions,
    containingPlaces,
    subDestinations,
    openingHours,
    secondaryOpeningHours,
    currentSecondaryOpeningHours,
    editorialSummary,
    generativeSummary,
    reviewSummary,
    reviews,
    parkingOptions,
    paymentOptions,
    fuelOptions,
    evChargeOptions,
    delivery,
    dineIn,
    takeout,
    curbsidePickup,
    reservable,
    servesBreakfast,
    servesBrunch,
    servesLunch,
    servesDinner,
    servesVegetarianFood,
    servesDessert,
    servesCoffee,
    servesBeer,
    servesWine,
    servesCocktails,
    outdoorSeating,
    liveMusic,
    menuForChildren,
    goodForChildren,
    goodForGroups,
    goodForWatchingSports,
    allowsDogs,
    restroom,
  ];

  @override
  bool operator ==(Object other) => other is PlaceField && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
