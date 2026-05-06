import 'package:flutter/material.dart';

import 'package:soltech_master_app/core/models/prediction_model.dart';

class PredictionPlacesUi extends StatelessWidget {
  const PredictionPlacesUi({
    super.key,
    required this.predictionPlacesData,
    required this.onPressed,
  });

  // The prediction data model containing place name and details.
  final PredictionModel predictionPlacesData;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // Neutral background so text reads like a list row.
        backgroundColor: Colors.grey[400],
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              // Location icon to visually indicate this is a place result.
              const Icon(Icons.share_location, color: Colors.black),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      // Primary place label (e.g., "Starbucks", "123 Main St").
                      predictionPlacesData.mainText ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // Secondary context (e.g., locality/region, "New York, NY").
                      predictionPlacesData.secondaryText ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
