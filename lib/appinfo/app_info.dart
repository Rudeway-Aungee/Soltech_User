import 'package:flutter/cupertino.dart';
import 'package:soltech_app/model/address_model.dart';

class AppInfo extends ChangeNotifier
{
  AddressModel? userPickupLocation;
  AddressModel? userDestinationLocation;

  void updatePickupLocationAddress(AddressModel pickupAddress)
  {
    userPickupLocation = pickupAddress;
    notifyListeners();
  }

  void updateDestinationLocationAddress(AddressModel destinationAddress)
  {
    userDestinationLocation = destinationAddress;
    notifyListeners();
  }
}