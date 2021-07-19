library sides;

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite/tflite.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:strings/strings.dart';

class CarSides {
  // final List<String> _sides = ['Front', 'Back', 'Left', 'Right', 'Diagonal'];
  static late List<String> sides;
  late String label;
  late double confidence;

  CarSides([this.label = "", this.confidence = 0.0]);

  CarSides.fromLetter(letter) {
    for (var side in sides) {
      if (capitalize(side[0]) == letter) {
        label = side;
        break;
      }
    }
    confidence = 0.0;
  }

  static loadAsset() async {
    sides = (await rootBundle.loadString('assets/labels.txt')).split("\n");
  }

  firstLetter() {
    return label[0].toUpperCase();
  }

  String toString() {
    return capitalize(label) + ' ' + confidenceToPercent();
  }

  String confidenceToPercent() {
    return "${(confidence * 100).round()}%";
  }
}

backup() async {
  print("Backing Up");
  var dir = await getExternalStorageDirectory();
  if (dir != null) {
    print("dir: $dir");
    dir.list(recursive: false).forEach((f) async {
      print("f: $f");
      var pred =
          '${f.path.split("/")[f.path.split("/").length - 1][0]}'.toUpperCase();
      var real =
          '${f.path.split("/")[f.path.split("/").length - 1][1]}'.toUpperCase();
      print("pred: $pred, real: $real");
      File fi = File(f.path);
      var uploaded = false;
      uploaded = await uploadImage(
          fi, new CarSides.fromLetter(pred), new CarSides.fromLetter(real));
      if (uploaded == true) {
        print("Uploaded, deleted");
        await fi.delete();
      }
    });
  }
}

Future<List<CarSides>> predict(
    File image) async //Predicts the image using the pretrained model
{
  await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false);

  var recognitions = await Tflite.runModelOnImage(
      path: image.path,
      imageMean: 117.0,
      imageStd: 1.0,
      numResults: 5,
      threshold: 0.1,
      asynch: true);
  print("recognitions: $recognitions");

  List<CarSides> carSidesList = [];
  recognitions!.forEach((element) =>
      carSidesList.add(CarSides(element['label'], element['confidence'])));
  // var result = [
  //   recognitions![0]['label'],
  //   recognitions[0]['confidence']
  // ];
  return carSidesList;
}

Future<bool> internetAvailable() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } on SocketException catch (_) {
    print('not connected');
    return false;
  }
  return false;
}

Future<bool> uploadImage(
    File image, CarSides predictedSide, CarSides realSide) async //In progress
{
  if (await internetAvailable()) {
    var now = DateTime.now();
    var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
    String currentTimeStamp = formatter.format(now);

    //XY_Cars -> X = predicted, Y=real
    var X = predictedSide.firstLetter();
    var Y = realSide.firstLetter();

    String fileName =
        X.toString() + Y.toString() + "_" + "Cars" + currentTimeStamp + ".jpg";

    print("Internet Available");
    var stream = new http.ByteStream(image.openRead());
    stream.cast();
    var length = await image.length();

    var uri = Uri.parse("https://carsides.coci.result.si/upload.php");

    var request = new http.MultipartRequest("POST", uri)
      ..fields['name'] = fileName
      ..fields['User-Agent'] = "mememe";

    var multipartFile = new http.MultipartFile('image', stream, length,
        filename: fileName, contentType: new MediaType('image', 'jpg'));

    request.files.add(multipartFile);
    var response = await request.send();
    print("statusCode: ${response.statusCode}");
    response.stream.transform(utf8.decoder).listen((value) {
      print("Answer: $value");
    });
    print("Image uploaded");
    return true;
  }
  print("Upload not successful!");
  return false;
}

save(File image, CarSides predictedSide,
    CarSides realSide) async //Saves picture in phone
{
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);

  //XY_Cars -> X = predicted, Y=real
  var X = predictedSide.firstLetter();
  var Y = realSide.firstLetter();

  String filename =
      X.toString() + Y.toString() + "_" + "Cars" + currentTimeStamp + ".jpg";

  print("filename: $filename");

  var appDir = await getExternalStorageDirectory();
  late String fileFullPath;
  if (appDir != null) {
    fileFullPath = appDir.path + '/' + filename;
  }

  final File localImage = await image.copy('$fileFullPath');
  print("localImage.path: ${localImage.path}");
}

Future<String> getFileSize(File file, int decimals) async {
  int bytes = await file.length();
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}
