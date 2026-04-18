import 'package:flutter/material.dart';
import '../model/prediction_model.dart';

class PredictionPlacesUi extends StatelessWidget {
  PredictionModel? predictionPlacesData;


   PredictionPlacesUi({super.key, this.predictionPlacesData});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed:()
        {

        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[400],
        ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.share_location,
                color: Colors.black,
              ),

              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      predictionPlacesData!.main_text!.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      predictionPlacesData!.secondary_text!.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    ]
              ),

      ),
      ]
          )
        ]
      )
    );
  }
}
