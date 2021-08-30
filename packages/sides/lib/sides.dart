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
import 'dart:math';

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

moldImage(List image) {
  // MEAN_PIXEL                     [123.7 116.8 103.9]
  var meanPixel = [123.7, 116.8, 103.9];
  for (int i = 0; i < image.length; i++) {
    for (int j = 0; j < image[i].length; j++)
      for (int k = 0; k < 3; k++) image[i][j][k] -= meanPixel[k];
  }
  return image;
}

composeImageMeta(
    imageId, originalImageShape, imageShape, window, scale, activeClassIds) {
  var meta = [imageId] +
      originalImageShape +
      imageShape +
      window +
      [scale] +
      activeClassIds;
  meta = List.generate(meta.length, (i) => meta[i].toDouble());
  return meta;
}

moldInputs(List image) {
// config.IMAGE_MIN_DIM 800
// config.IMAGE_MIN_SCALE 0
// config.IMAGE_MAX_DIM 1024
// config.IMAGE_RESIZE_MODE square
  var resizeOutput = resizeImage(image,
      minDim: 800, maxDim: 1024, minScale: 0, mode: 'square');
  List moldedImage = resizeOutput[0];
  var window = resizeOutput[1];
  var scale = resizeOutput[2];
  var padding = resizeOutput[3];
  var crop = resizeOutput[4];

  var zerosList = [];
  for (int i = 0; i < 81; i++) {
    zerosList.add(0);
  }

  moldedImage = moldImage(moldedImage);
  List imageMeta = composeImageMeta(
      0, image.shape, moldedImage.shape, window, scale, zerosList);
  return [
    [moldedImage],
    [imageMeta],
    [window]
  ];
}

resizeImage(List image, {minDim, maxDim, minScale, mode = "square"}) {
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
  // if (minDim != null)
  //   // Scale up but not down
  //   scale = max(1, minDim / min(h, w));
  // if (minScale != null && scale < minScale) scale = minScale;

  // Does it exceed max dim?
  // var imageMax;
  // if (maxDim != null && mode == "square") {
  //   imageMax = max(h, w);
  //   if ((imageMax * scale) > maxDim) scale = maxDim / imageMax;
  // }
  //
  // if(mode == "square")
  //   {
  //     var topPad = (maxDim - h) ~/ 2;
  //     var bottomPad = maxDim - h - topPad;
  //     var leftPad = (maxDim - w) ~/ 2;
  //     var rightPad = maxDim - w - leftPad;
  //     padding = [[topPad, bottomPad], [leftPad, rightPad], [0, 0]];
  //   }
  return [image, window, scale, padding, crop];
}

computeBackboneShapes(List imageShape, backboneStrides) {
  List output = [];
  for (var value in backboneStrides) {
    output
        .add([(imageShape[0] / value).ceil(), (imageShape[1] / value).ceil()]);
  }
  return output;
}

generateAnchors(scales, ratios, shape, featureStride, int anchorStride) {
  scales = List.generate(ratios.length, (index) => scales);

  var heights = List.generate(
      ratios.length, (index) => scales[index] / sqrt(ratios[index]));
  var widths = List.generate(
      ratios.length, (index) => scales[index] * sqrt(ratios[index]));
  var shiftsY = [];
  for (var i = 0; i < shape[0]; i += anchorStride) {
    shiftsY.add(i * featureStride);
  }
  var shiftsX = [];
  for (var i = 0; i < shape[1]; i += anchorStride) {
    shiftsX.add(i * featureStride);
  }
  var meshGridOut = meshGrid(shiftsX, shiftsY);
  shiftsX = meshGridOut[0];
  shiftsY = meshGridOut[1];
  var meshGridOutX = meshGrid(widths, shiftsX);
  List boxWidths = meshGridOutX[0];
  List boxCentersX = meshGridOutX[1];

  var meshGridOutY = meshGrid(heights, shiftsY);
  List boxHeights = meshGridOutY[0];
  List boxCentersY = meshGridOutY[1];

  List boxCenters = stackAxis2(boxCentersY, boxCentersX);
  List boxSizes = stackAxis2(boxHeights, boxWidths);
  var boxes = concatenateAxis1(boxCenters, boxSizes);
  return boxes;
}

concatenateAxis1(List x, List y) {
  var output = [];
  for (var i = 0; i < x.length; i++) {
    var temp = [];
    for (var j = 0; j < x[i].length; j++) {
      temp.add(x[i][j] - 0.5 * y[i][j]);
    }
    for (var j = 0; j < x[i].length; j++) {
      temp.add(x[i][j] + 0.5 * y[i][j]);
    }
    output.add(temp);
  }
  return output;
}

stackAxis2(List x, List y) {
  List output = [];
  for (var i = 0; i < x.length; i++) {
    for (var j = 0; j < x[i].length; j++) output.add([x[i][j], y[i][j]]);
  }
  return output;
}

meshGrid(List x, List y) {
  var outputX = [];
  var outputY = [];

  var flattenX = [];
  if (x[0] is List)
    x.forEach((e) {
      flattenX.addAll(e);
    });
  else
    flattenX = x;

  var flattenY = [];
  if (y[0] is List)
    y.forEach((e) {
      flattenY.addAll(e);
    });
  else
    flattenY = y;

  for (var i = 0; i < flattenY.length; i++) {
    var tempX = [];
    var tempY = [];
    for (var j = 0; j < flattenX.length; j++) {
      tempX.add(flattenX[j]);
      tempY.add(flattenY[i]);
    }
    outputX.add(tempX);
    outputY.add(tempY);
  }
  return [outputX, outputY];
}

generatePyramidAnchors(
    List scales, ratios, featureShapes, featureStrides, int anchorStride) {
  var anchors = [];
  for (var i = 0; i < scales.length; i++) {
    anchors.add(generateAnchors(
        scales[i], ratios, featureShapes[i], featureStrides[i], anchorStride));
  }
  var pyramidAnchors = [];
  for (var i in anchors) {
    pyramidAnchors.addAll(i);
  }
  return pyramidAnchors;
}

getAnchors(List imageShape) {
  var RPN_ANCHOR_SCALES = [32, 64, 128, 256, 512];
  var RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  var BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  var RPN_ANCHOR_STRIDE = 1;

  var backboneShapes = computeBackboneShapes(imageShape, BACKBONE_STRIDES);
  var anchorCache = {};
  var anchors = generatePyramidAnchors(RPN_ANCHOR_SCALES, RPN_ANCHOR_RATIOS,
      backboneShapes, BACKBONE_STRIDES, RPN_ANCHOR_STRIDE);
  // TODO: make as global var
  anchorCache[imageShape] = normBoxes(anchors, [imageShape[0], imageShape[1]]);
  return anchorCache[imageShape];
}

normBoxes(boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];

  var output = [];
  for (var box in boxes) {
    var temp = [];
    for (var i = 0; i < box.length; i++) {
      temp.add((box[i] - shift[i]) / scale[i]);
    }
    output.add(temp);
  }
  return output;
}

predict(Img image) async //Predicts the image using the pretrained model
{
  final interpreter = await tfl.Interpreter.fromAsset('model.tflite');
  var byteList = bytesToArray(image.image!);

  var moldOutput = moldInputs(byteList);
  List<List> moldedImages = moldOutput[0];
  List imageMetas = moldOutput[1];
  List windows = moldOutput[2];

  var anchors = [getAnchors(moldedImages[0].shape)];
  print('${moldedImages.shape} ${imageMetas.shape}, ${anchors.shape}');
  print(moldedImages);
  print(imageMetas);
  print(anchors);
  var inputs = [moldedImages, imageMetas, anchors];

  var outputs = {
    0: [
      List.filled(1000, [0.0, 0.0, 0.0, 0.0])
    ],
    1: [
      List.filled(1000, List.filled(81, [0.0, 0.0, 0.0, 0.0]))
    ],
    2: [List.filled(1000, List.filled(81, 0.0))],
    3: [List.filled(100, List.filled(6, 0.0))],
    4: [
      List.filled(100, List.filled(28, List.filled(28, List.filled(81, 0.0))))
    ],
    5: [List.filled(261888, List.filled(4, 0.0))],
    6: [List.filled(261888, List.filled(2, 0.0))]
  };
  print('start inference');
  interpreter.runForMultipleInputs(inputs, outputs);
  print('end inference');
  for(var i = 0; i < 7; i++)
    {
      print(outputs[i]);
    }
  // print(outputs[0]);
/*  for(var out in outputs[3]![0])
    {
      for(var num in out)
        {
          if(num != 0.0)
            {
              print(out);
            }
        }
    }
  print(outputs[3]);
  print(outputs[4]);*/
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
