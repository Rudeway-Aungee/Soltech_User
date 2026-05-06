// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

/// Places Autocomplete prediction value object.
///
/// Parsed from the Google Places Autocomplete response and used for rendering
/// selectable search results.
class PredictionModel {
  // Unique identifier for the place from Google Places database.
  String? placeId;
  // Primary text (e.g., "Starbucks", "123 Main St").
  String? mainText;
  // Secondary text (e.g., "New York, NY" or "Coffee Shop").
  String? secondaryText;

  PredictionModel({this.placeId, this.mainText, this.secondaryText});

  /// Factory constructor to parse a prediction from Google Places Autocomplete JSON.
  /// Safely extracts nested fields with null-coalescing to handle missing keys.
  PredictionModel.fromJson(Map<String, dynamic> json) {
    // Use `as String?` to tolerate missing keys in API responses.
    placeId = json['place_id'] as String?;
    // Places response nests text under `structured_formatting` object.
    // This provides pre-formatted main and secondary text for display.
    mainText = (json['structured_formatting'] as Map<String, dynamic>?)?['main_text'] as String?;
    secondaryText =
        (json['structured_formatting'] as Map<String, dynamic>?)?['secondary_text'] as String?;
  }
}
