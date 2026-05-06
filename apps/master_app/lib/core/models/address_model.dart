// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

/// Address/location value object used throughout the app.
///
/// Represents a resolved map location with coordinates and a human-readable
/// label.
class AddressModel {

  // Full formatted address string (e.g., "123 Main St, New York, NY 10001").
  String? humanReadableAddress;
  // Latitude coordinate for map positioning and routing.
  double? latitudePosition;
  // Longitude coordinate for map positioning and routing.
  double? longitudePosition;
  // Unique identifier from Google Places API for detailed place lookups.
  String? placeID;
  // Display name for the location (often same as humanReadableAddress initially).
  String? placeName;

  AddressModel( {
    // `humanReadableAddress` and `placeName` are often identical for pickup
    // until we enrich with more structured details.
    this.humanReadableAddress,
    // Coordinates used for camera, routing, and pricing logic.
    this.latitudePosition,
    this.longitudePosition,
    // `placeID` comes from Google APIs when available.
    this.placeID,
    this.placeName
  });
}
