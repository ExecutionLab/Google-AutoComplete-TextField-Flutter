// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/material.dart';

class PlacesAutocompleteResponse {
  List<Prediction> predictions = [];

  PlacesAutocompleteResponse();

  PlacesAutocompleteResponse.fromMap(Map<String, dynamic> map) {
    if (map['suggestions'] != null) {
      final List suggestions = map['suggestions'] ?? [];
      predictions = suggestions.map((v) => Prediction.fromMap(v['placePrediction'])).toList();
    }
  }
}

class Prediction {
  final String placeId;
  final String text;
  final String mainText;

  Prediction({
    required this.placeId,
    required this.text,
    required this.mainText,
  });

  factory Prediction.fromMap(Map<String, dynamic> map) {
    debugPrint("$map\n");
    return Prediction(
      placeId: map['placeId'] ?? "",
      text: map['text']['text'] ?? "",
      mainText: map['structuredFormat']['mainText']['text'] ?? "",
    );
  }
}

class PlaceDetail {
  final String id;
  final String formattedAddress;
  final Location location;
  final String displayName;

  PlaceDetail(
      {required this.id,
      required this.formattedAddress,
      required this.location,
      required this.displayName});

  factory PlaceDetail.fromMap(Map<String, dynamic> map) {
    return PlaceDetail(
      id: map['id'] as String,
      formattedAddress: map['formattedAddress'] as String,
      location: Location.fromMap(map['location']),
      displayName: map['displayName']['text'] as String,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }
}
