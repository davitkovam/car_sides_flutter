library sides;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strings/strings.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class Img {
  File? file;
  ImagePackage.Image? image;
  String? size;
  late Future _doneFuture;

  String? path;

  Img({this.path, this.file}) {
    if (path != null) this.file = File(path!);
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

  init() async {
    size = await getFileSize(file!, 2);
  }

  int get width => image!.width;

  int get height => image!.height;

  String get resolution => "$width" + "x" + "$height";

  String toString() => resolution + " " + size!;

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

  firstLetter() => capitalize(label[0]);

  String toString() => capitalize(label) + ' ' + confidenceToPercent();

  String confidenceToPercent() => "${(confidence * 100).round()}%";
}

class CarPartsConfig {
  static const List<int> BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  static const int IMAGE_MAX_DIM = 512;
  static const int IMAGE_MIN_DIM = 512;
  static const int IMAGE_MIN_SCALE = 0;
  static const String IMAGE_RESIZE_MODE = 'square';
  static const List<double> MEAN_PIXEL = [123.7, 116.8, 103.9];
  static const int NUM_CLASSES = 19;
  static const List<double> RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  static const List<double> RPN_ANCHOR_SCALES = [8, 16, 32, 64, 128];
  static const int RPN_ANCHOR_STRIDE = 1;
  static const List classNames = [
    'BG',
    'back_bumper',
    'back_glass',
    'back_left_door',
    'back_left_light',
    'back_right_door',
    'back_right_light',
    'front_bumper',
    'front_glass',
    'front_left_door',
    'front_left_light',
    'front_right_door',
    'front_right_light',
    'hood',
    'left_mirror',
    'right_mirror',
    'tailgate',
    'trunk',
    'wheel'
  ];
}

List imageTo3DList(ImagePackage.Image image) {
  List rgbImage = image.getBytes(format: ImagePackage.Format.rgb);
  rgbImage = rgbImage.reshape([image.height, image.width, 3]);
  return rgbImage;
}

List moldInputs(ImagePackage.Image image) {
  var resizeOutput = resizeImage(image,
      minDim: CarPartsConfig.IMAGE_MIN_DIM,
      maxDim: CarPartsConfig.IMAGE_MAX_DIM,
      minScale: CarPartsConfig.IMAGE_MIN_SCALE,
      mode: CarPartsConfig.IMAGE_RESIZE_MODE);
  List moldedImage = resizeOutput[0];
  var window = resizeOutput[1];
  var scale = resizeOutput[2];
  // var padding = resizeOutput[3];
  // var crop = resizeOutput[4];
  moldedImage = moldImage(moldedImage);
  var zerosList = List.filled(CarPartsConfig.NUM_CLASSES, 0);
  var imageMeta = composeImageMeta(0, [image.height, image.width, 3],
      moldedImage.shape, window, scale, zerosList);
  return [
    [moldedImage],
    [imageMeta],
    [window]
  ];
}

List resizeImage(ImagePackage.Image image,
    {minDim, maxDim, minScale, mode = "square"}) {
  var h = image.height;
  var w = image.width;
  List imageList = imageTo3DList(image);

  var window = [0, 0, h, w];
  var scale = 1.0;
  var padding = [
    [0, 0],
    [0, 0],
    [0, 0]
  ];
  var crop;

  if (mode == "none") return [image, window, scale, padding, crop];

  // Scale?
  if (minDim != null)
    // Scale up but not down
    scale = max(1, minDim / min(h, w));
  if (minScale != null && scale < minScale) scale = minScale;
  // Does it exceed max dim?
  var imageMax;

  if (maxDim != null && mode == "square") {
    imageMax = max(h, w);
    if ((imageMax * scale) > maxDim) scale = maxDim / imageMax;
  }
  if (scale != 1) {
    if (imageMax == h) {
      image = ImagePackage.copyResize(image, width: minDim);
    } else {
      image = ImagePackage.copyResize(image, height: minDim);
    }
    image = ImagePackage.copyRotate(image, -90);
  }

  if (mode == "square") {
    var h = image.height;
    var w = image.width;
    int topPad = (maxDim - h) ~/ 2;
    var bottomPad = maxDim - h - topPad;
    int leftPad = (maxDim - w) ~/ 2;
    var rightPad = maxDim - w - leftPad;
    padding = [
      [topPad, bottomPad],
      [leftPad, rightPad],
      [0, 0]
    ];
    imageList = imageTo3DList(image);
    imageList = addPadding(imageList, padding);
    window = [topPad, leftPad, h + topPad, w + leftPad];
  }
  imageList = imageList.flatten();
  imageList = List.generate(imageList.length, (i) => imageList[i].toDouble());
  imageList = imageList.reshape([maxDim, maxDim, 3]);
  return [imageList, window, scale, padding, crop];
}

List addPadding(List image, List padding) {
  var w = image.shape[1];
  if (padding[0].any((element) => element != 0)) {
    for (var i = 0; i < padding[0][0]; i++)
      image.insert(0, List.filled(w, [0, 0, 0]));
    for (var i = 0; i < padding[0][1]; i++)
      image.add(List.filled(w, [0, 0, 0]));
  } else if (padding[1].any((element) => element != 0)) {
    for (var i = 0; i < padding[1][0]; i++)
      image.forEach((element) => element.insert(0, [0, 0, 0]));
    for (var i = 0; i < padding[1][1]; i++)
      image.forEach((element) => element.add([0, 0, 0]));
  }
  return image;
}

List moldImage(List image) {
  for (int i = 0; i < image.length; i++)
    for (int j = 0; j < image[i].length; j++)
      for (int k = 0; k < 3; k++)
        image[i][j][k] -= CarPartsConfig.MEAN_PIXEL[k];

  return image;
}

List composeImageMeta(
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

Future<List> getAnchors(List imageShape) async {
  Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
  String appDocumentsPath = appDocumentsDirectory.path;

  var filename = '$appDocumentsPath/anchors';
  for (var shape in imageShape) filename += '_$shape';
  filename += '.json';
  if (await File(filename).exists()) {
    print('Anchors exist');
    return jsonDecode(await File(filename).readAsString());
  }
  print('Anchors don\'t exist');
  var backboneShapes =
      computeBackboneShapes(imageShape, CarPartsConfig.BACKBONE_STRIDES);
  var anchors = generatePyramidAnchors(
      CarPartsConfig.RPN_ANCHOR_SCALES,
      CarPartsConfig.RPN_ANCHOR_RATIOS,
      backboneShapes,
      CarPartsConfig.BACKBONE_STRIDES,
      CarPartsConfig.RPN_ANCHOR_STRIDE);
  anchors = normBoxes(anchors, [imageShape[0], imageShape[1]]);
  await File(filename).writeAsString(jsonEncode(anchors));
  return anchors;
}

List computeBackboneShapes(List imageShape, List<int> backboneStrides) {
  var output = [];
  for (int value in backboneStrides)
    output
        .add([(imageShape[0] / value).ceil(), (imageShape[1] / value).ceil()]);

  return output;
}

List generatePyramidAnchors(List scales, List ratios, List featureShapes,
    featureStrides, int anchorStride) {
  var anchors = [];
  for (var i = 0; i < scales.length; i++) {
    anchors.add(generateAnchors(
        scales[i], ratios, featureShapes[i], featureStrides[i], anchorStride));
  }
  var pyramidAnchors = [];
  for (var anchor in anchors) {
    pyramidAnchors.addAll(anchor);
  }
  return pyramidAnchors;
}

List generateAnchors(scales, ratios, shape, featureStride, int anchorStride) {
  scales = List.generate(ratios.length, (index) => scales);

  var heights =
      List.generate(ratios.length, (i) => scales[i] / sqrt(ratios[i]));
  var widths = List.generate(ratios.length, (i) => scales[i] * sqrt(ratios[i]));
  var shiftsY = [];
  for (var i = 0; i < shape[0]; i += anchorStride) {
    shiftsY.add(i * featureStride);
  }
  var shiftsX = [];
  for (var i = 0; i < shape[1]; i += anchorStride) {
    shiftsX.add(i * featureStride);
  }
  var shiftsXY = meshGrid(shiftsX, shiftsY);
  var boxWidthsCentersX = meshGrid(widths, shiftsXY[0]);
  var boxHeightsCentersY = meshGrid(heights, shiftsXY[1]);
  var boxCenters = stack(boxHeightsCentersY[1], boxWidthsCentersX[1]);
  var boxSizes = stack(boxHeightsCentersY[0], boxWidthsCentersX[0]);
  var boxes = concatenate(boxCenters, boxSizes);
  return boxes;
}

List meshGrid(List x, List y) {
  var flattenX = x.flatten();
  var flattenY = y.flatten();
  var outputX = List.generate(flattenY.length,
      (i) => List.generate(flattenX.length, (j) => flattenX[j]));
  var outputY = List.generate(flattenY.length,
      (i) => List.generate(flattenX.length, (j) => flattenY[i]));
  return [outputX, outputY];
}

List stack(List x, List y, {axis = 2}) {
  var output = [];
  for (var i = 0; i < x.shape[0]; i++)
    for (var j = 0; j < x.shape[1]; j++) output.add([x[i][j], y[i][j]]);

  return output;
}

List concatenate(List x, List y, {axis = 1}) {
  var output = [];
  for (var i = 0; i < x.shape[0]; i++) {
    output.add(List.generate(x.shape[1], (j) => x[i][j] - 0.5 * y[i][j]) +
        List.generate(x.shape[1], (j) => x[i][j] + 0.5 * y[i][j]));
  }
  return output;
}

List normBoxes(boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];
  var output = [];
  for (var box in boxes) {
    output
        .add(List.generate(box.length, (i) => (box[i] - shift[i]) / scale[i]));
  }
  return output;
}

List unmoldDetections(
    detections, List mrcnnMask, originalImageShape, imageShape, window) {
  var N = detections.length;
  for (var i = 0; i < detections.length; i++) {
    if (detections[i][4] == 0) {
      N = i;
      break;
    }
  }
  var boxes = [];
  var classIds = [];
  var scores = [];
  List masks = [];

  if (N == 0) return [boxes, classIds, scores, masks];

  for (var i = 0; i < N; i++) {
    boxes.add(List.generate(4, (j) => detections[i][j]));
    classIds.add(detections[i][4].toInt());
    scores.add(detections[i][5]);
    var tempList = [];
    for (var j = 0; j < mrcnnMask[i].length; j++) {
      var tempList2 = [];
      for (var k = 0; k < mrcnnMask[i][j].length; k++) {
        tempList2.add(mrcnnMask[i][j][k][classIds[i]]);
      }
      tempList.add(tempList2);
    }
    masks.add(tempList);
  }
  window = normBoxes([window], imageShape)[0];
  var wy1 = window[0];
  var wx1 = window[1];
  var wy2 = window[2];
  var wx2 = window[3];
  var shift = [wy1, wx1, wy1, wx1];
  var wh = wy2 - wy1;
  var ww = wx2 - wx1;
  var scale = [wh, ww, wh, ww];
  for (var i = 0; i < boxes.shape[0]; i++) {
    for (var j = 0; j < boxes.shape[1]; j++) {
      boxes[i][j] = (boxes[i][j] - shift[j]) / scale[j];
    }
  }
  boxes = denormBoxes(boxes, originalImageShape);
  Function eq = const ListEquality().equals;
  var boxesOutput = [];
  var equals = false;
  for (var box in boxes) {
    for (var boxOut in boxesOutput) {
      if (eq(box, boxOut)) {
        equals = true;
        break;
      }
    }
    if (!equals)
      boxesOutput.add(box);
    else
      equals = false;
  }
  boxes = boxesOutput;
  N = boxes.length;
  List fullMasks = [];
  for (var i = 0; i < N; i++) {
    var fullMask = unmoldMask(masks[i], boxes[i], originalImageShape);
    fullMasks.add(fullMask);
  }
  return [boxes, classIds, scores, fullMasks];
}

List denormBoxes(List boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];
  for (var i = 0; i < boxes.shape[0]; i++) {
    for (var j = 0; j < boxes.shape[1]; j++) {
      boxes[i][j] = (boxes[i][j] * scale[j] + shift[j]).round();
    }
  }
  return boxes;
}

List unmoldMask(List mask, bbox, imageShape) {
  var threshold = 0.5;
  int y1 = bbox[0];
  int x1 = bbox[1];
  int y2 = bbox[2];
  int x2 = bbox[3];
  var boolMask = List.generate(
      mask.shape[0],
      (i) => List.generate(mask.shape[1],
          (j) => mask[i][j] >= threshold ? [255, 255, 255] : [0, 0, 0]));
  var maskImage = ImagePackage.Image.fromBytes(
      mask.shape[0], mask.shape[1], boolMask.flatten(),
      format: ImagePackage.Format.rgb);
  maskImage =
      ImagePackage.copyResize(maskImage, width: x2 - x1, height: y2 - y1);
  mask = imageTo3DList(maskImage);
  var binaryMask = [];
  Function eq = const ListEquality().equals;
  for (var i = 0; i < mask.shape[0]; i++) {
    for (var j = 0; j < mask.shape[1]; j++) {
      if (eq(mask[i][j], [0, 0, 0]))
        binaryMask.add(false);
      else
        binaryMask.add(true);
    }
  }
  binaryMask = binaryMask.reshape([mask.shape[0], mask.shape[1]]);
  var fullMask = List.generate(
      imageShape[0],
      (i) => List.generate(
          imageShape[1],
          (j) => (i >= y1 && i < y2 && j >= x1 && j < x2)
              ? binaryMask[i - y1][j - x1]
              : false));

  return fullMask;
}

displayInstances(List image, List boxes, List masks, List classIds, classNames,
    {scores, title, showMask = true, showBbox = true, colors, captions}) async {
  if (boxes.isEmpty) {
    print("No instances to display");
    return;
  }
  var N = boxes.shape[0];
  if (colors == null) {
    colors = randomColors(N);
  }

  var height = image.shape[0];
  var width = image.shape[1];

  ImagePackage.Image maskedImage = ImagePackage.Image.fromBytes(
      width, height, image.flatten(),
      format: ImagePackage.Format.rgb);
  for (var i = 0; i < N; i++) {
    Color color = colors[i];
    //     if not np.any(boxes[i]):
    // # Skip this instance. Has no bbox. Likely lost in image cropping.
    // continue
    var y1 = boxes[i][0];
    var x1 = boxes[i][1];
    var y2 = boxes[i][2];
    var x2 = boxes[i][3];

    maskedImage = ImagePackage.drawRect(maskedImage, x1, y1, x2, y2,
        ImagePackage.getColor(color.red, color.green, color.blue));

    var mask = masks[i];
    if (showMask) maskedImage = applyMask(maskedImage, mask, color);

    if (captions == null) {
      var classId = classIds[i];
      var score = scores != null ? scores[i] : null;
      var label = CarPartsConfig.classNames[classId];
      var caption =
          score != null ? '$label ${score.toStringAsFixed(3)}' : '$label';
      maskedImage = ImagePackage.drawString(
          maskedImage, ImagePackage.arial_24, x1, y1 + 8, caption);
    }
  }
  Directory appCacheDirectory = await getTemporaryDirectory();
  String appCachesPath = appCacheDirectory.path;
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);
  var filename = '$appCachesPath/$currentTimeStamp.png';
  await File(filename).writeAsBytes(ImagePackage.encodePng(maskedImage));
  return filename;
}

randomColors(N, [bright = true]) {
  var brightness = bright ? 1.0 : 0.7;
  var hsv = List.generate(
      N, (i) => HSVColor.fromAHSV(1.0, i / N * 360.0, 1.0, brightness));
  var rgb = List.generate(N, (i) => hsv[i].toColor());
  // var rgb = List.generate(N, (i) =>[hsv[i].toColor().red, hsv[i].toColor().green, hsv[i].toColor().blue]);
  rgb.shuffle();
  return rgb;
}

ImagePackage.Image applyMask(
    ImagePackage.Image maskedImage, List mask, Color color,
    {alpha = 0.5}) {
  var maskImageList = List.generate(
      mask.shape[0],
      (i) => List.generate(
          mask.shape[1],
          (j) => mask[i][j]
              ? [color.red, color.green, color.blue, (255 * alpha).toInt()]
              : [0, 0, 0, 0]));
  var maskImage = ImagePackage.Image.fromBytes(
      mask.shape[1], mask.shape[0], maskImageList.flatten());
  maskedImage = ImagePackage.drawImage(maskedImage, maskImage);
  return maskedImage;
}

predict(
    ImagePackage.Image
        image) async //Predicts the image using the pretrained model
{
  print('predict()');
  final interpreter = await tfl.Interpreter.fromAsset('car_parts.tflite');
  var moldOutput = moldInputs(image);
  List moldedImages = moldOutput[0];
  List imageMetas = moldOutput[1];
  List windows = moldOutput[2];
  var anchors = [await getAnchors(moldedImages.shape.sublist(1))];
  var inputs = [moldedImages, imageMetas, anchors];
  var outputTensors = interpreter.getOutputTensors();
  var outputShapes = [];
  outputTensors.forEach((tensor) {
    outputShapes.add(tensor.shape);
  });

  var detections = TensorBufferFloat(outputShapes[3]);
  var mrcnnMask = TensorBufferFloat(outputShapes[4]);
  var outputs = <int, Object>{};
  for (var i = 0; i < outputTensors.length; i++) {
    if (i == 3)
      outputs[i] = detections.buffer;
    else if (i == 4)
      outputs[i] = mrcnnMask.buffer;
    else
      outputs[i] = TensorBufferFloat(outputShapes[i]).buffer;
  }
  print('Start inference');
  var inferenceTimeStart = DateTime.now().millisecondsSinceEpoch;
  interpreter.runForMultipleInputs(inputs, outputs);
  interpreter.close();
  var inferenceTimeElapsed =
      DateTime.now().millisecondsSinceEpoch - inferenceTimeStart;
  FLog.info(
      className: "Sides",
      methodName: "predict",
      text: "Inference took ${inferenceTimeElapsed / 1000} secs");

  print('End inference');
  List detectionsList = detections.getDoubleList().reshape(outputShapes[3]);
  List mrcnnMaskList = mrcnnMask.getDoubleList().reshape(outputShapes[4]);
  var unmoldOutput = unmoldDetections(detectionsList[0], mrcnnMaskList[0],
      imageTo3DList(image).shape, moldedImages.shape.sublist(1), windows[0]);
  var finalRois = unmoldOutput[0];
  var finalClassIds = unmoldOutput[1];
  var finalScores = unmoldOutput[2];
  var finalMasks = unmoldOutput[3];
  FLog.info(
      className: "Sides",
      methodName: "predict",
      text: "Found ${finalRois.length} instances");
  var filename = await displayInstances(imageTo3DList(image), finalRois,
      finalMasks, finalClassIds, CarPartsConfig.classNames,
      scores: finalScores);
  print(filename);
  return filename;
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
    File image, CarSides predictedSide, CarSides realSide) async {
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

void save(File image, CarSides predictedSide,
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

Future<void> backup() async {
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

Future<String> getFileSize(File file, int decimals) async {
  int bytes = await file.length();
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}
