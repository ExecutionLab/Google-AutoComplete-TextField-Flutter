library google_places_flutter;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_places_flutter/model/prediction.dart';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import 'DioErrorHandler.dart';

class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  InputDecoration inputDecoration;
  ItemClick? itemClick;
  GetPlaceDetail? getPlaceDetail;
  bool isLatLngRequired = true;

  TextStyle textStyle;
  String googleAPIKey;
  int debounceTime = 600;

  /// Default is Japan
  String languageCode;
  TextEditingController textEditingController = TextEditingController();
  ListItemBuilder? itemBuilder;
  Widget? seperatedBuilder;
  void clearData;
  BoxDecoration? boxDecoration;
  bool isCrossBtnShown;
  bool showError;
  double? containerHorizontalPadding;
  double? containerVerticalPadding;
  int? maxLength;

  GooglePlaceAutoCompleteTextField(
      {required this.textEditingController,
      required this.googleAPIKey,
      this.maxLength,
      this.debounceTime = 600,
      this.inputDecoration = const InputDecoration(),
      this.itemClick,
      this.isLatLngRequired = true,
      this.textStyle = const TextStyle(),
      this.languageCode = 'ja',
      this.getPlaceDetail,
      this.itemBuilder,
      this.boxDecoration,
      this.isCrossBtnShown = true,
      this.seperatedBuilder,
      this.showError = true,
      this.containerHorizontalPadding,
      this.containerVerticalPadding});

  @override
  _GooglePlaceAutoCompleteTextFieldState createState() => _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState extends State<GooglePlaceAutoCompleteTextField> {
  final subject = new PublishSubject<String>();
  OverlayEntry? _overlayEntry;
  List<Prediction> alPredictions = [];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  bool isCrossBtn = true;
  late Dio _dio;

  CancelToken? _cancelToken = CancelToken();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: widget.containerHorizontalPadding ?? 0,
            vertical: widget.containerVerticalPadding ?? 0),
        alignment: Alignment.centerLeft,
        decoration: widget.boxDecoration ??
            BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: Colors.grey, width: 0.6),
                borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                decoration: widget.inputDecoration,
                style: widget.textStyle,
                controller: widget.textEditingController,
                maxLength: widget.maxLength,
                onChanged: (string) {
                  subject.add(string);
                  if (widget.isCrossBtnShown) {
                    isCrossBtn = string.isNotEmpty ? true : false;
                    setState(() {});
                  }
                },
              ),
            ),
            (!widget.isCrossBtnShown)
                ? SizedBox()
                : isCrossBtn && _showCrossIconWidget()
                    ? IconButton(onPressed: clearData, icon: Icon(Icons.close))
                    : SizedBox()
          ],
        ),
      ),
    );
  }

  getLocation(String text) async {
    if (text.isEmpty) {
      return;
    }

    String url = "https://places.googleapis.com/v1/places:autocomplete";

    final json = {
      "input": text,
      "languageCode": widget.languageCode,
      "sessionToken": Uuid().v4(),
    };

    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
      _cancelToken = CancelToken();
    }

    try {
      Response response = await _dio.post(
        url,
        data: jsonEncode(json),
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            "content-type": "application/json",
            "X-Goog-Api-Key": widget.googleAPIKey,
          },
        ),
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      Map map = response.data;
      if (map.containsKey("error_message")) {
        throw response.data;
      }

      PlacesAutocompleteResponse subscriptionResponse =
          PlacesAutocompleteResponse.fromMap(response.data);

      if (text.length == 0) {
        alPredictions.clear();
        this._overlayEntry!.remove();
        return;
      }

      isSearched = false;
      alPredictions.clear();
      if (subscriptionResponse.predictions.length > 0 &&
          (widget.textEditingController.text.toString().trim()).isNotEmpty) {
        alPredictions.addAll(subscriptionResponse.predictions);
      }

      this._overlayEntry = null;
      this._overlayEntry = this._createOverlayEntry();
      Overlay.of(context).insert(this._overlayEntry!);
    } catch (e) {
      _showSnackBar("${e}");
    }
  }

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  textChanged(String text) async {
    getLocation(text);
  }

  OverlayEntry? _createOverlayEntry() {
    if (context.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (context) => Positioned(
                left: offset.dx,
                top: size.height + offset.dy,
                width: size.width,
                child: CompositedTransformFollower(
                  showWhenUnlinked: false,
                  link: this._layerLink,
                  offset: Offset(0.0, size.height + 5.0),
                  child: Material(
                      child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: alPredictions.length,
                    separatorBuilder: (context, pos) => widget.seperatedBuilder ?? SizedBox(),
                    itemBuilder: (BuildContext context, int index) {
                      return InkWell(
                        onTap: () {
                          var selectedData = alPredictions[index];
                          if (index < alPredictions.length) {
                            widget.itemClick!(selectedData);

                            if (widget.isLatLngRequired) {
                              getPlaceDetailsFromPlaceId(selectedData);
                            }
                            removeOverlay();
                          }
                        },
                        child: widget.itemBuilder != null
                            ? widget.itemBuilder!(context, index, alPredictions[index])
                            : Container(
                                padding: EdgeInsets.all(10),
                                child: Text(alPredictions[index].mainText),
                              ),
                      );
                    },
                  )),
                ),
              ));
    }
    return null;
  }

  removeOverlay() {
    alPredictions.clear();
    this._overlayEntry = this._createOverlayEntry();
    Overlay.of(context).insert(this._overlayEntry!);
    this._overlayEntry!.markNeedsBuild();
  }

  Future<Response?> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    final url =
        "https://places.googleapis.com/v1/places/${prediction.placeId}?languageCode=${widget.languageCode}";
    Response response = await _dio.get(
      url,
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          "content-type": "application/json",
          "X-Goog-Api-Key": widget.googleAPIKey,
          "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
        },
      ),
    );

    PlaceDetail placeDetail = PlaceDetail.fromMap(response.data);

    widget.getPlaceDetail!(placeDetail);
    return null;
  }

  void clearData() {
    widget.textEditingController.clear();
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
    }

    setState(() {
      alPredictions.clear();
      isCrossBtn = false;
    });

    if (this._overlayEntry != null) {
      try {
        this._overlayEntry?.remove();
      } catch (e) {}
    }
  }

  _showCrossIconWidget() {
    return (widget.textEditingController.text.isNotEmpty);
  }

  _showSnackBar(String errorData) {
    if (widget.showError) {
      final snackBar = SnackBar(
        content: Text("$errorData"),
      );

      // Find the ScaffoldMessenger in the widget tree
      // and use it to show a SnackBar.
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetail = void Function(PlaceDetail postalCodeResponse);

typedef ListItemBuilder = Widget Function(BuildContext context, int index, Prediction prediction);
