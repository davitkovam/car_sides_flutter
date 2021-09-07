library sides;

import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:strings/strings.dart';
import 'package:f_logs/f_logs.dart';
import 'package:image/image.dart' as ImagePackage;

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

  Future init() async {
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

class CocoConfig {
  static const String BACKBONE = 'resnet101';
  static const List<int> BACKBONE_STRIDES = [4, 8, 16, 32, 64];
  static const int BATCH_SIZE = 1;
  static const List<double> BBOX_STD_DEV = [0.1, 0.1, 0.2, 0.2];

  // static COMPUTE_BACKBONE_SHAPE = None;
  static const int DETECTION_MAX_INSTANCES = 100;
  static const double DETECTION_MIN_CONFIDENCE = 0.7;
  static const double DETECTION_NMS_THRESHOLD = 0.3;
  static const int FPN_CLASSIF_FC_LAYERS_SIZ = 1024;
  static const int GPU_COUNT = 1;
  static const double GRADIENT_CLIP_NORM = 5.0;
  static const int IMAGES_PER_GPU = 1;
  static const int IMAGE_CHANNEL_COUNT = 3;
  static const int IMAGE_MAX_DIM = 1024;
  static const int IMAGE_META_SIZE = 93;
  static const int IMAGE_MIN_DIM = 800;
  static const int IMAGE_MIN_SCALE = 0;
  static const String IMAGE_RESIZE_MODE = 'square';
  static const List<int> IMAGE_SHAPE = [1024, 1024, 3];
  static const double LEARNING_MOMENTUM = 0.9;
  static const double LEARNING_RATE = 0.001;
  static const Map<String, double> LOSS_WEIGHTS = {
    'rpn_class_loss': 1.0,
    'rpn_bbox_loss': 1.0,
    'mrcnn_class_loss': 1.0,
    'mrcnn_bbox_loss': 1.0,
    'mrcnn_mask_loss': 1.0
  };
  static const int MASK_POOL_SIZE = 14;
  static const List<int> MASK_SHAPE = [28, 28];
  static const int MAX_GT_INSTANCES = 100;
  static const List<double> MEAN_PIXEL = [123.7, 116.8, 103.9];
  static const List<int> MINI_MASK_SHAPE = [56, 56];
  static const String NAME = 'coco';
  static const int NUM_CLASSES = 81;
  static const int POOL_SIZE = 7;
  static const int POST_NMS_ROIS_INFERENCE = 1000;
  static const int POST_NMS_ROIS_TRAINING = 2000;
  static const int PRE_NMS_LIMIT = 6000;
  static const double ROI_POSITIVE_RATIO = 0.33;
  static const List<double> RPN_ANCHOR_RATIOS = [0.5, 1, 2];
  static const List<double> RPN_ANCHOR_SCALES = [32, 64, 128, 256, 512];
  static const int RPN_ANCHOR_STRIDE = 1;
  static const List<double> RPN_BBOX_STD_DEV = [0.1, 0.1, 0.2, 0.2];
  static const double RPN_NMS_THRESHOLD = 0.7;
  static const int RPN_TRAIN_ANCHORS_PER_IMAGE = 256;
  static const int STEPS_PER_EPOCH = 1000;
  static const int TOP_DOWN_PYRAMID_SIZE = 256;
  static const bool TRAIN_BN = false;
  static const int TRAIN_ROIS_PER_IMAGE = 200;
  static const bool USE_MINI_MASK = true;
  static const bool USE_RPN_ROIS = true;
  static const int VALIDATION_STEPS = 50;
  static const double WEIGHT_DECAY = 0.0001;
  static const List classNames = [
    'BG',
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush'
  ];
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
  List rgbImage = image.getBytes(format: ImagePackage.Format.rgb);
  // rgbImage = List.generate(rgbImage.length, (i) => rgbImage[i].toDouble());
  rgbImage = rgbImage.reshape([image.height, image.width, 3]);
  return rgbImage;
}

moldInputs(List image) {
  var resizeOutput = resizeImage(image,
      minDim: CocoConfig.IMAGE_MIN_DIM,
      maxDim: CocoConfig.IMAGE_MAX_DIM,
      minScale: CocoConfig.IMAGE_MIN_SCALE,
      mode: CocoConfig.IMAGE_RESIZE_MODE);
  List moldedImage = resizeOutput[0];
  var window = resizeOutput[1];
  var scale = resizeOutput[2];
  // var padding = resizeOutput[3];
  // var crop = resizeOutput[4];
  moldedImage = moldImage(moldedImage);
  var zerosList = List.filled(CocoConfig.NUM_CLASSES, 0);
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
  // TODO: resize
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

moldImage(image) {
  for (int i = 0; i < image.length; i++)
    for (int j = 0; j < image[i].length; j++)
      for (int k = 0; k < 3; k++) image[i][j][k] -= CocoConfig.MEAN_PIXEL[k];

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

getAnchors(List imageShape) async {
  Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
  String appDocumentsPath = appDocumentsDirectory.path;

  var filename = '$appDocumentsPath/anchors';
  for (var shape in imageShape) filename += '_$shape';
  filename += '.json';
  if (await File(filename).exists()) {
    print('Anchors exist');
    return jsonDecode(await File(filename).readAsString());
  }

  var backboneShapes =
      computeBackboneShapes(imageShape, CocoConfig.BACKBONE_STRIDES);
  var anchors = generatePyramidAnchors(
      CocoConfig.RPN_ANCHOR_SCALES,
      CocoConfig.RPN_ANCHOR_RATIOS,
      backboneShapes,
      CocoConfig.BACKBONE_STRIDES,
      CocoConfig.RPN_ANCHOR_STRIDE);
  anchors = normBoxes(anchors, [imageShape[0], imageShape[1]]);
  await File(filename).writeAsString(jsonEncode(anchors));
  return anchors;
}

computeBackboneShapes(List imageShape, List<int> backboneStrides) {
  List output = [];
  for (int value in backboneStrides)
    output
        .add([(imageShape[0] / value).ceil(), (imageShape[1] / value).ceil()]);

  return output;
}

generatePyramidAnchors(List scales, List ratios, List featureShapes,
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

generateAnchors(scales, ratios, shape, featureStride, int anchorStride) {
  scales = List.generate(ratios.length, (index) => scales);

  var heights = List.generate(
      ratios.length, (i) => scales[i] / sqrt(ratios[i]));
  var widths = List.generate(
      ratios.length, (i) => scales[i] * sqrt(ratios[i]));
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

meshGrid(List x, List y) {
  var outputX = [];
  var outputY = [];

  var flattenX = x.flatten();
  var flattenY = y.flatten();

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

stackAxis2(List x, List y) {
  List output = [];
  for (var i = 0; i < x.length; i++) {
    for (var j = 0; j < x[i].length; j++) output.add([x[i][j], y[i][j]]);
  }
  return output;
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

unmoldDetections(
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
  for (var i = 0; i < N; i++) {
    boxes.add(List.generate(4, (index) => detections[i][index]));
    classIds.add(detections[i][4].toInt());
    scores.add(detections[i][5]);
    var tempList = [];
    for (var j = 0; j < mrcnnMask[i].length; j++) {
      var tempList2  = [];
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
  for (var i = 0; i < boxes.length; i++) {
    for (var j = 0; j < boxes[i].length; j++) {
      boxes[i][j] = (boxes[i][j] - shift[j]) / scale[j];
    }
  }
  boxes = denormBoxes(boxes, originalImageShape);
  List fullMasks = [];
  for (var i = 0; i < N; i++) {
    var fullMask = unmoldMask(masks[i], boxes[i], originalImageShape);
    fullMasks.add(fullMask);
  }
  var fullMasksStack = [];
  if (fullMasks.isNotEmpty) {
    print('fullMasks not empty');
    for (var i = 0; i < fullMasks[0].length; i++) {
      var tempList2 = [];
      for (var j = 0; j < fullMasks[0][0].length; j++) {
        var tempList = [];
        for (var k = 0; k < fullMasks.length; k++) {
          tempList.add(fullMasks[k][i][j]);
        }
        tempList2.add(tempList);
      }
      fullMasksStack.add(tempList2);
    }
  } else {
    print('fullMasks empty :(');
  }
  return [boxes, classIds, scores, fullMasksStack];
}

denormBoxes(List boxes, shape) {
  var h = shape[0];
  var w = shape[1];
  var scale = [h - 1, w - 1, h - 1, w - 1];
  var shift = [0, 0, 1, 1];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = 0; j < boxes[i].length; j++) {
      boxes[i][j] = (boxes[i][j] * scale[j] + shift[j]).round();
    }
  }
  return boxes;
}

unmoldMask(mask, bbox, imageShape) {
  // var threshold = 0.5;
  // var y1 = bbox[0];
  // var x1 = bbox[1];
  // var y2 = bbox[2];
  // var x2 = bbox[3];
  // TODO: resize mask
  var fullMask = List.generate(imageShape[0],
      (index) => List<bool>.generate(imageShape[1], (index) => false));
/*  for (var i = y1; i < y2; i++) {
    for (var j = x1; j < x2; j++) {
      fullMask[i][j] = mask[i - y1][j - x1];
    }
  }*/
  return fullMask;
}

displayInstances(List image, List boxes, List masks, List classIds, classNames,
    {scores, title, showMask = true, showBbox = true, colors, captions}) async {
  print(image);
  var N = boxes.shape[0];
/*  if (N == 0) {
    print("No instances to display");
  } else {
    assert((boxes.shape[0] == masks.shape[3]) == classIds.shape[0]);
  }*/
  if (colors == null) {
    colors = randomColors(N);
  }

  var height = image.shape[0];
  var width = image.shape[1];

  ImagePackage.Image maskedImage = ImagePackage.Image.fromBytes(
      width, height, image.flatten(),
      format: ImagePackage.Format.rgb);
  print(maskedImage.getBytes(format: ImagePackage.Format.rgb));
  for (var i = 0; i < N; i++) {
    var color = colors[i];
    //     if not np.any(boxes[i]):
    // # Skip this instance. Has no bbox. Likely lost in image cropping.
    // continue
    var y1 = boxes[i][0];
    var x1 = boxes[i][1];
    var y2 = boxes[i][2];
    var x2 = boxes[i][3];

    maskedImage = ImagePackage.drawRect(maskedImage, x1, y1, x2, y2, color);
    if (captions == null) {
      var classId = classIds[i];
      var score = scores != null ? scores[i] : null;
      var label = CocoConfig.classNames[classId];
      var caption = score != null ? '$label $score' : '$label';
      maskedImage = ImagePackage.drawString(
          maskedImage, ImagePackage.arial_14, x1, y1 + 8, caption,
          color: color);
    }
    // TODO: Mask
  }
  Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
  String appDocumentsPath = appDocumentsDirectory.path;
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);
  var filename = '$appDocumentsPath/$currentTimeStamp.png';
  filename = '/storage/emulated/0/Download/$currentTimeStamp.png';
  await File(filename).writeAsBytes(ImagePackage.encodePng(maskedImage));
  return filename;
}

randomColors(N, [bright = true]) {
  var brightness = bright ? 1.0 : 0.7;
  var hsv = List.generate(
      N, (i) => HSVColor.fromAHSV(1.0, i / N * 360.0, 1.0, brightness));
  var rgb = List.generate(N, (i) => hsv[i].toColor().value);
  // var rgb = List.generate(N, (i) =>[hsv[i].toColor().red, hsv[i].toColor().green, hsv[i].toColor().blue]);
  rgb.shuffle();
  return rgb;
}

predict(ImagePackage.Image image) async //Predicts the image using the pretrained model
{
  print('predict');
  final interpreter = await tfl.Interpreter.fromAsset('model.tflite');
  List imageList = bytesToArray(image);
  var moldOutput = moldInputs(imageList);
  List<List> moldedImages = moldOutput[0];
  List imageMetas = moldOutput[1];
  List windows = moldOutput[2];
  var anchors = [await getAnchors(moldedImages[0].shape)];
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
  print('start inference');
  interpreter.runForMultipleInputs(inputs, outputs);
  interpreter.close();
  print('end inference');
  List detectionsList = detections.getDoubleList().reshape(outputShapes[3]);
  List mrcnnMaskList = mrcnnMask.getDoubleList().reshape(outputShapes[4]);
/*  var json_detections =
      jsonDecode(await rootBundle.loadString('assets/detections.json'));
  List detections = json_detections['detections'];
  List mrcnnMask = json_detections['mrcnn_mask'];
  List imageList = json_detections['image'];
  List moldedImages = json_detections['molded_image'];
  List windows = json_detections['windows'];
  detections[2][4] = 0;*/
  var unmoldOutput = await unmoldDetections(detectionsList[0], mrcnnMaskList[0],
      imageList.shape, moldedImages[0].shape, windows[0]);
  var finalRois = unmoldOutput[0];
  var finalClassIds = unmoldOutput[1];
  var finalScores = unmoldOutput[2];
  var finalMasks = unmoldOutput[3];
  var filename = await displayInstances(
      bytesToArray(image), finalRois, finalMasks, finalClassIds, CocoConfig.classNames,
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
