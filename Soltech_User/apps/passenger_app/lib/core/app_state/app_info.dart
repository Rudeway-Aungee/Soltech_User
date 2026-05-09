// CODE COMMENTS -------------------------------------------------------------
// Purpose: Stores passenger pickup, destination, and stop selections so multiple screens can share trip state.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// AppInfo is shared passenger trip state.
// It stores the current pickup, destination, and optional intermediate stops selected by the passenger.
// Provider notifies screens when these locations change so the map and ride summary update automatically.
// ---------------------------------------------------------------------------

import 'package:flutter/cupertino.dart';
import 'package:soltech_app/core/models/address_model.dart';

class AppInfo extends ChangeNotifier {
  AddressModel? userPickupLocation;
  AddressModel? userDestinationLocation;
  List<AddressModel> intermediateStops = [];

  void updatePickupLocationAddress(AddressModel pickupAddress) {
    // Publish pickup updates to any listeners (e.g., home page bottom sheet).
    userPickupLocation = pickupAddress;
    notifyListeners();
  }

  void updateDestinationLocationAddress(AddressModel destinationAddress) {
    // Publish destination updates to any listeners (e.g., route/price calculation).
    userDestinationLocation = destinationAddress;
    notifyListeners();
  }

  void addIntermediateStop(AddressModel stopAddress) {
    intermediateStops.add(stopAddress);
    notifyListeners();
  }

  void updateIntermediateStop(int index, AddressModel stopAddress) {
    if (index >= 0 && index < intermediateStops.length) {
      intermediateStops[index] = stopAddress;
      notifyListeners();
    }
  }

  void removeIntermediateStop(int index) {
    if (index >= 0 && index < intermediateStops.length) {
      intermediateStops.removeAt(index);
      notifyListeners();
    }
  }

  void clearIntermediateStops() {
    intermediateStops.clear();
    notifyListeners();
  }

  void clearTripSelection({bool keepPickup = true}) {
    if (!keepPickup) {
      userPickupLocation = null;
    }

    userDestinationLocation = null;
    intermediateStops.clear();
    notifyListeners();
  }
}
