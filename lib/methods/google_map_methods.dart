import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http show Response, get;
import 'package:provider/provider.dart' show Provider;
import 'package:soltech_app/appinfo/app_info.dart' show AppInfo;
import 'package:soltech_app/global.dart';
import 'package:flutter/material.dart';
import 'package:soltech_app/model/address_model.dart';

class GoogleMapMethods {

  static Future<dynamic> sendRequestToAPI(String apiUrl) async {

    http.Response responseFromAPI = await http.get(Uri.parse(apiUrl));

    try {
      if (responseFromAPI.statusCode == 200) {
        String dataFromApi;
        dataFromApi = responseFromAPI.body;
        var dataDecoded = jsonDecode(dataFromApi);
        return dataDecoded;
      }
      else {
        return "error";
      }
    }
    catch (erroMsg) {
      return "error";
    }
  }


  ///Reverse  Geocoding: Get address from latitude and longitude
  static Future<String> convertGeoGraphicCoOrdinatesIntoHumanReadableAddress(
      Position position, BuildContext context) async
  {
    String humanReadableAddress = "";
    String geoCodingApiUrl = "https://maps.googleapis.com/maps/api/geocode/json?lat,lng=${position.latitude},${position.longitude}&key=$googleMapKey";

    var responseFromAPI = await sendRequestToAPI(geoCodingApiUrl);

    if(responseFromAPI != "error")
      {
        humanReadableAddress = responseFromAPI["results"][0]["formatted_address"];

        AddressModel userCurrentAddress = AddressModel();
        userCurrentAddress.humanReadableAddress = humanReadableAddress;
        userCurrentAddress.placeName = humanReadableAddress;
        userCurrentAddress.placeID = responseFromAPI["results"][0]["place_id"];
        userCurrentAddress.latitudePosition = position.latitude;
        userCurrentAddress.longitudePosition = position.longitude;

        Provider.of<AppInfo>(context, listen: false).updatePickupLocationAddress(userCurrentAddress);

      }

    return humanReadableAddress;

  }
}