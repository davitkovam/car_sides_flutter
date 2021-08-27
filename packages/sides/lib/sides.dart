library sides;

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// import 'package:tflite/tflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:strings/strings.dart';
import 'package:f_logs/f_logs.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:color/color.dart';

class Img {
  File? file;
  ImagePackage.Image? image;
  String? size;
  late Future _doneFuture;

  String? path;

  Img({this.path, this.file}) {
    if (path != null) {
      this.file = File(path!);
    }
    image = ImagePackage.decodeImage(file!.readAsBytesSync());
    _doneFuture = init();
  }

  setPath(path) => this.path = path;

  crop(int x, int y, int w, int h) async {
    image = ImagePackage.copyCrop(image!, x, y, w, h);
    File(path!).writeAsBytesSync(ImagePackage.encodeJpg(image!));
    file = File(path!);
    await init();
  }

  resize(int width, int height) async {
    image = ImagePackage.copyResize(image!, width: width, height: height);
    File(path!).writeAsBytesSync(ImagePackage.encodeJpg(image!));
    file = File(path!);
    await init();
  }

  Future init() async {
    size = await getFileSize(file!, 2);
  }

  int get width => image!.width;

  int get height => image!.height;

  String get resolution => "$width" + "x" + "$height";

  String toString() {
    return resolution + " " + size!;
  }

  Future get initializationDone => _doneFuture;
}

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
    return capitalize(label[0]);
  }

  String toString() {
    return capitalize(label) + ' ' + confidenceToPercent();
  }

  String confidenceToPercent() {
    return "${(confidence * 100).round()}%";
  }
}

backup() async {
  FLog.info(className: "Sides", methodName: "Backup", text: "Backing Up");
  var dir = await getExternalStorageDirectory();
  if (dir != null) {
    FLog.info(
        className: "Sides", methodName: "Backup", text: "Directory: $dir");
    dir.list(recursive: false).forEach((f) async {
      if (f.path.contains(".jpg")) {
        FLog.info(className: "Sides", methodName: "Backup", text: "f: $f");
        var pred = '${f.path.split("/")[f.path.split("/").length - 1][0]}'
            .toUpperCase();
        var real = '${f.path.split("/")[f.path.split("/").length - 1][1]}'
            .toUpperCase();
        FLog.info(
            className: "Sides",
            methodName: "Backup",
            text: "pred: $pred, real: $real");
        File fi = File(f.path);
        var uploaded = false;
        uploaded = await uploadImage(
            fi, new CarSides.fromLetter(pred), new CarSides.fromLetter(real));
        if (uploaded == true) {
          FLog.info(
              className: "Sides",
              methodName: "Backup",
              text: "Uploaded, deleted");
          await fi.delete();
        }
      }
    });
  }
}

bytesToArray(ImagePackage.Image image) {
  var bytes = image.getBytes();
  // (256, 256, 3)
  var outputList = [];

  for (var i = 0; i < image.height; i++) {
    var tempList = [];
    for (var j = 0; j < image.width; j++) {
      var rgbList = [];
      for (var k = 0; k < 3; k++) {
        rgbList.add(bytes[i + (j * 4) + k]);
      }
      tempList.add(rgbList);
    }
    outputList.add(tempList);
  }
  // print(outputList);
  return outputList;
}

moldInputs(List image) {
// config.IMAGE_MIN_DIM 800
// config.IMAGE_MIN_SCALE 0
// config.IMAGE_MAX_DIM 1024
// config.IMAGE_RESIZE_MODE square
  resizeImage(image, minDim: 800, maxDim: 1024, minScale: 0, mode: 'square');
}

resizeImage(List image, {minDim, maxDim, minScale, mode = "square"}) {
  print(image.shape);
  var h = image.shape[0];
  var w = image.shape[1];

  var window = [0, 0, h, w];
  var scale = 1;
  var padding = [
    [0, 0],
    [0, 0],
    [0, 0]
  ];
  var crop;

  if (mode == "none") return [image, window, scale, padding, crop];

  // Scale?
  if (minDim)
    // Scale up but not down
    scale = max(1, minDim / min(h, w));
  if (minScale && scale < minScale) scale = minScale;

  // Does it exceed max dim?
  var imageMax;
  if (maxDim && mode == "square") {
    imageMax = max(h, w);
    if ((imageMax * scale).round() > maxDim) scale = maxDim / imageMax;
  }

  // Resize image using bilinear interpolation
  // if(scale != 1)


}

predict(Img image) async //Predicts the image using the pretrained model
{
  final interpreter = await tfl.Interpreter.fromAsset('model.tflite');
  print('image');
  var byteList = bytesToArray(image.image!);
  var newImage = image.resize(1024, 1024);
  // moldInputs(byteList);

  // var input0 = [];
  // input0.add([]);
  // for (var i = 0; i < 1024; i++) {
  //   print('in for loop');
  //   var tempX = [];
  //   for (var j = 0; j < 1024; j++) {
  //     tempX.add([0.0, 0.0, 0.0]);
  //   }
  //   input0[0].add(tempX);
  // }
  // print('input shape:');
  // print(input0.shape);
  //
  // var input1 = [];
  // input1.add([]);
  // for (var i = 0; i < 93; i++) {
  //   input1[0].add(0.0);
  // }
  // print(input1.shape);
  //
  // var input2 = [];
  // input2.add([]);
  // for (var i = 0; i < 261888; i++) {
  //   input2[0].add([0.0, 0.0, 0.0, 0.0]);
  // }
  // print(input2.shape);
  // // input: List<Object>
  // var inputs = [input0, input1, input2];
  //
  // var output0 = [
  //   List.filled(1000, [0.0, 0.0, 0.0, 0.0])
  // ];
  // var output1 = [
  //   List.filled(1000, List.filled(81, [0.0, 0.0, 0.0, 0.0]))
  // ];
  // var output2 = [List.filled(1000, List.filled(81, 0.0))];
  // var output3 = [List.filled(100, List.filled(6, 0.0))];
  // var output4 = [
  //   List.filled(100, List.filled(28, List.filled(28, List.filled(81, 0.0))))
  // ];
  // var output5 = [List.filled(261888, List.filled(4, 0.0))];
  // var output6 = [List.filled(261888, List.filled(2, 0.0))];
  //
  // print(output0.shape);
  // print(output1.shape);
  // print(output2.shape);
  // print(output3.shape);
  // print(output4.shape);
  // print(output5.shape);
  // print(output6.shape);
  //
  // // output: Map<int, Object>
  // var outputs = {
  //   0: output0,
  //   1: output1,
  //   2: output2,
  //   3: output3,
  //   4: output4,
  //   5: output5,
  //   6: output6
  // };
  //
  // // inference
  // print('start inference');
  // interpreter.runForMultipleInputs(inputs, outputs);
  // print('end inference');
  // // print outputs
  // print(outputs);
}

Future<bool> internetAvailable() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } on SocketException catch (_) {
    FLog.info(
        className: "Sides",
        methodName: "internetAvailable",
        text: "not connected");
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
    String X = predictedSide.firstLetter();
    String Y = realSide.firstLetter();

    String fileName = X + Y + "_" + "Cars" + currentTimeStamp + ".jpg";
    // print(fileName);
    FLog.info(
        className: "Sides",
        methodName: "uploadImage",
        text: "Internet Available");
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
    FLog.info(
        className: "Sides",
        methodName: "uploadImage",
        text: "statusCode: ${response.statusCode}");
    response.stream.transform(utf8.decoder).listen((value) {
      FLog.info(
          className: "Sides",
          methodName: "uploadImage",
          text: "Answer: $value");
    });
    FLog.info(
        className: "Sides", methodName: "uploadImage", text: "Image uploaded");
    return true;
  }
  FLog.info(
      className: "Sides",
      methodName: "uploadImage",
      text: "Upload not successful!");
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

  FLog.info(
      className: "Sides", methodName: "Save", text: "filename: $filename");
  var appDir = await getExternalStorageDirectory();
  late String fileFullPath;
  if (appDir != null) {
    fileFullPath = appDir.path + '/' + filename;
  }

  final File localImage = await image.copy('$fileFullPath');
  FLog.info(
      className: "Sides",
      methodName: "Save",
      text: "localImage.path: ${localImage.path}");
}

Future<String> getFileSize(File file, int decimals) async {
  int bytes = await file.length();
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}
