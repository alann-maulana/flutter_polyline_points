import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../src/PointLatLng.dart';
import '../src/utils/polyline_waypoint.dart';
import '../src/utils/request_enums.dart';
import 'utils/polyline_result.dart';

class NetworkUtil {
  static const String STATUS_OK = "ok";

  NetworkUtil(this.webProxy);

  final String? webProxy;

  ///Get the encoded string from google directions api
  ///
  Future<PolylineResult> getRouteBetweenCoordinates(
      String googleApiKey,
      PointLatLng origin,
      PointLatLng destination,
      TravelMode travelMode,
      List<PolylineWayPoint> wayPoints,
      bool avoidHighways,
      bool avoidTolls,
      bool avoidFerries,
      bool optimizeWaypoints) async {
    String mode = travelMode.toString().replaceAll('TravelMode.', '');
    PolylineResult result = PolylineResult();
    var params = {
      "origin": "${origin.latitude},${origin.longitude}",
      "destination": "${destination.latitude},${destination.longitude}",
      "mode": mode,
      "avoidHighways": "$avoidHighways",
      "avoidFerries": "$avoidFerries",
      "avoidTolls": "$avoidTolls",
      "key": googleApiKey
    };
    if (wayPoints.isNotEmpty) {
      List wayPointsArray = [];
      wayPoints.forEach((point) => wayPointsArray.add(point.location));
      String wayPointsString = wayPointsArray.join('|');
      if (optimizeWaypoints) {
        wayPointsString = 'optimize:true|$wayPointsString';
      }
      params.addAll({"waypoints": wayPointsString});
    }
    Uri uri =
        Uri.https("maps.googleapis.com", "maps/api/directions/json", params);

    if (kIsWeb && webProxy != null) {
      uri = Uri.parse('${webProxy!}${uri.toString()}');
    }

    // print('GOOGLE MAPS URL: ' + url);
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      var parsedJson = json.decode(response.body);
      result.status = parsedJson["status"];
      if (parsedJson["status"]?.toLowerCase() == STATUS_OK &&
          parsedJson["routes"] != null &&
          parsedJson["routes"].isNotEmpty) {
        result.points = decodeEncodedPolyline(
            parsedJson["routes"][0]["overview_polyline"]["points"]);
      } else {
        result.errorMessage = parsedJson["error_message"];
      }
    }
    return result;
  }

  ///decode the google encoded string using Encoded Polyline Algorithm Format
  /// for more info about the algorithm check https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  ///
  ///return [List]
  List<PointLatLng> decodeEncodedPolyline(String encoded) {
    List<PointLatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    BigInt Big0 = BigInt.from(0);
    BigInt Big0x1f = BigInt.from(0x1f);
    BigInt Big0x20 = BigInt.from(0x20);

    while (index < len) {
      int shift = 0;
      BigInt b, result;
      result = Big0;
      do {
        b = BigInt.from(encoded.codeUnitAt(index++) - 63);
        result |= (b & Big0x1f) << shift;
        shift += 5;
      } while (b >= Big0x20);
      BigInt rShifted = result >> 1;
      int dLat;
      if (result.isOdd)
        dLat = (~rShifted).toInt();
      else
        dLat = rShifted.toInt();
      lat += dLat;

      shift = 0;
      result = Big0;
      do {
        b = BigInt.from(encoded.codeUnitAt(index++) - 63);
        result |= (b & Big0x1f) << shift;
        shift += 5;
      } while (b >= Big0x20);
      rShifted = result >> 1;
      int dLng;
      if (result.isOdd)
        dLng = (~rShifted).toInt();
      else
        dLng = rShifted.toInt();
      lng += dLng;

      poly.add(PointLatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }
}
