library sides;

import 'package:path/path.dart' as path;

import 'package:tflite/tflite.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';

import 'package:flutter/material.dart';

predict(File? image) async //Predicts the image using the pretrained model
    {
  String? res = await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false);

  var recognitions = await Tflite.runModelOnImage(
      path: image!.path,
      imageMean: 117.0,
      imageStd: 1.0,
      numResults: 5,
      threshold: 0.1,
      asynch: true);

  var result = recognitions![0]['label'] +
      "," +
      recognitions[0]['confidence'].toStringAsPrecision(3);

  return result;
}

internetAvailable() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return 1;
    }
  } on SocketException catch (_) {
    print('not connected');
    return 0;
  }
  return 0;
}

uploadImage(File? image, String? pred, String real) async //In progress
    {
  if (await internetAvailable() == 1) {
    var now = DateTime.now();
    var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
    String currentTimeStamp = formatter.format(now);
    print(currentTimeStamp);

    //XY_Cars -> X = predicted, Y=real
    var X = '${pred![0]}'.toUpperCase();
    var Y = '${real[0]}'.toUpperCase();

    String fname =
        X.toString() + Y.toString() + "_" + "Cars" + currentTimeStamp + ".jpg";

    print("Internet Available");
    var stream = new http.ByteStream(DelegatingStream.typed(image!.openRead()));
    var length = await image.length();

    var uri = Uri.parse("https://carsides.coci.result.si/upload.php");

    var request = new http.MultipartRequest("POST", uri)
      ..fields['name'] = fname
      ..fields['User-Agent'] = "mememe";
    var multipartFile = new http.MultipartFile('image', stream, length,
        filename: fname, contentType: new MediaType('image', 'jpg'));

    request.files.add(multipartFile);
    var response = await request.send();
    print("statusCode: ${response.statusCode}");
    response.stream.transform(utf8.decoder).listen((value) {
      print("listen: $value");
    });
    print("uploaded image");
    return true;
  }
  print("Upload not successful!");
  return false;
}

save(File? image, String? pred, String real) async //Saves picture in phone
    {
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);
  print(currentTimeStamp);

  //XY_Cars -> X = predicted, Y=real
  var X = '${pred![0]}'.toUpperCase();
  var Y = '${real[0]}'.toUpperCase();

  String filename =
      X.toString() + Y.toString() + "_" + "Cars" + currentTimeStamp + ".jpg";

  print(filename);

  var appDir = await getExternalStorageDirectory();
  String? dir = "";
  if (appDir != null) {
    dir = appDir.path;
  }
  print(dir);
  if (dir != null) {
    dir += "/" + filename;
  }

  if (image != null) {
    final File localImage = await image.copy('$dir');
    print(localImage.path);
  }
}
