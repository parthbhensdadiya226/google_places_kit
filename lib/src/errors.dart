/// What went wrong in a [PlacesException].
enum PlacesErrorCode {
  /// The API key is wrong or deleted.
  invalidApiKey(
    'The API key is not valid. Check that it is copied correctly and still '
    'exists in Google Cloud Console.',
  ),

  /// The API isn't turned on for the key's project.
  apiNotEnabled(
    'This API is not enabled for the key\'s project. Enable "Places API '
    '(New)" and "Geocoding API" in Google Cloud Console.',
  ),

  /// The project has no billing account.
  billingNotEnabled(
    'Billing is not enabled for the key\'s project. Google requires a '
    'billing account, even within the free monthly usage.',
  ),

  /// The key's restrictions don't allow this app, website or API.
  keyRestricted(
    'The API key\'s restrictions block this request. Check its allowed APIs '
    'and its app or website restrictions in Google Cloud Console.',
  ),

  /// The key may not be used for this request.
  permissionDenied('The request was refused by Google.'),

  /// A quota or rate limit was reached.
  quotaExceeded(
    'A quota or rate limit was reached. Try again later, or raise the quota '
    'in Google Cloud Console.',
  ),

  /// Something in the request is wrong, such as an unknown place type.
  invalidRequest('The request was not valid.'),

  /// The place doesn't exist, or its ID is too old.
  notFound('The place was not found. Its ID may be wrong or outdated.'),

  /// No connection, or the request timed out.
  network('Could not reach Google. Check the internet connection.'),

  /// Google had a problem. Trying again may work.
  server('Google had a temporary problem. Try again.'),

  /// Anything else.
  unknown('Something went wrong.');

  const PlacesErrorCode(this.description);

  /// What the code means, in plain words.
  final String description;
}

/// An error from [GooglePlaces].
class PlacesException implements Exception {
  /// Creates an exception.
  const PlacesException(
    this.code, {
    this.serverMessage,
    this.statusCode,
    this.reason,
  });

  /// What went wrong.
  final PlacesErrorCode code;

  /// The message Google sent, if any. Often has details, such as the
  /// project number or a link to enable the API.
  final String? serverMessage;

  /// The HTTP status code, if Google answered.
  final int? statusCode;

  /// Google's own error reason, such as `API_KEY_INVALID` or
  /// `REQUEST_DENIED`.
  final String? reason;

  /// [code]'s description, in plain words.
  String get message => code.description;

  @override
  String toString() => [
    'PlacesException(${code.name}): $message',
    if (serverMessage != null) 'Google says: $serverMessage',
  ].join(' ');
}
