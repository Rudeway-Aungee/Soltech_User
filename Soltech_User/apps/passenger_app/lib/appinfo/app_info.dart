import 'package:flutter/cupertino.dart';
import 'package:soltech_app/model/address_model.dart';

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
