import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pytorch_mobile/enums/dtype.dart';
import 'package:pytorch_mobile/model.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:pytorch_mobile/pytorch_mobile.dart';
import 'package:flutter_charts/flutter_charts.dart';

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

List imageTo3DList(img.Image image) {
  List rgbImage = image.getBytes(format: img.Format.bgr);
  rgbImage = rgbImage.reshape([image.height, image.width, 3]);
  return rgbImage;
}

Future<List> moldInputs(img.Image image) async {
  var resizeOutput = await resizeImage(image,
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

Future<List> resizeImage(img.Image image,
    {minDim, maxDim, minScale, mode = "square"}) async {
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
  var imageBlack = img.Image.rgb(imageMax, imageMax);
  imageBlack = img.fill(imageBlack, img.getColor(0, 0, 0));
  if (scale != 1) {
    if (imageMax == h) {
      image =
          img.drawImage(imageBlack, image, dstX: (imageMax - min(h, w)) ~/ 2);
      image = img.copyResize(image, height: minDim);
    } else {
      image = img.copyResize(image, height: minDim);
    }
    // image = img.copyRotate(image, -90);
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
  var moldPath = '/storage/emulated/0/Download/molded_image.png';
  await File(moldPath).writeAsBytes(img.encodePng(img.Image.fromBytes(
      imageList.shape[1], imageList.shape[0], imageList.flatten(),
      format: img.Format.rgb)));

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

Future<List> unmoldDetections(
    detections, List mrcnnMask, originalImageShape, imageShape, window) async {
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
    var fullMask = await unmoldMask(masks[i], boxes[i], originalImageShape);
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

Future<List> unmoldMask(List mask, bbox, imageShape) async {
  var threshold = 0.5;
  int y1 = bbox[0];
  int x1 = bbox[1];
  int y2 = bbox[2];
  int x2 = bbox[3];
  print(mask);
  var boolMask = List.generate(
      mask.shape[0],
      (i) => List.generate(mask.shape[1],
          (j) => mask[i][j] >= threshold ? [255, 255, 255] : [0, 0, 0]));
  var secondMask = List.generate(
      mask.shape[0],
      (i) => List.generate(
          mask.shape[1], (j) => List.filled(3, (mask[i][j] * 255).round())));
  print(secondMask);
  var maskImage = img.Image.fromBytes(
      mask.shape[0], mask.shape[1], secondMask.flatten(),
      format: img.Format.rgb);
  print(x2 - x1);
  print(y2 - y1);
  maskImage = img.copyResize(maskImage, width: x2 - x1, height: y2 - y1);
  mask = imageTo3DList(maskImage);
  print(mask);
  var binaryMask = [];
  Function eq = const ListEquality().equals;
  for (var i = 0; i < mask.shape[0]; i++) {
    for (var j = 0; j < mask.shape[1]; j++) {
      if (mask[i][j][0] >= 255 * 0.5)
        binaryMask.add(true);
      else
        binaryMask.add(false);
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

  img.Image maskedImage = img.Image.fromBytes(width, height, image.flatten(),
      format: img.Format.rgb);
  for (var i = 0; i < N; i++) {
    Color color = colors[i];
    //     if not np.any(boxes[i]):
    // # Skip this instance. Has no bbox. Likely lost in image cropping.
    // continue
    var y1 = boxes[i][0];
    var x1 = boxes[i][1];
    var y2 = boxes[i][2];
    var x2 = boxes[i][3];

    maskedImage = img.drawRect(maskedImage, x1, y1, x2, y2,
        img.getColor(color.red, color.green, color.blue));

    var mask = masks[i];
    if (showMask) maskedImage = applyMask(maskedImage, mask, color);

    if (captions == null) {
      var classId = classIds[i];
      var score = scores != null ? scores[i] : null;
      var label = CarPartsConfig.classNames[classId];
      var caption =
          score != null ? '$label ${score.toStringAsFixed(3)}' : '$label';
      maskedImage =
          img.drawString(maskedImage, img.arial_24, x1, y1 + 8, caption);
    }
  }
  Directory appCacheDirectory = await getTemporaryDirectory();
  String appCachesPath = appCacheDirectory.path;
  var now = DateTime.now();
  var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
  String currentTimeStamp = formatter.format(now);
  var filename = '$appCachesPath/$currentTimeStamp.png';
  await File(filename).writeAsBytes(img.encodePng(maskedImage));
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

img.Image applyMask(img.Image maskedImage, List mask, Color color,
    {alpha = 0.5}) {
  var maskImageList = List.generate(
      mask.shape[0],
      (i) => List.generate(
          mask.shape[1],
          (j) => mask[i][j]
              ? [color.red, color.green, color.blue, (255 * alpha).toInt()]
              : [0, 0, 0, 0]));
  var maskImage = img.Image.fromBytes(
      mask.shape[1], mask.shape[0], maskImageList.flatten());
  maskedImage = img.drawImage(maskedImage, maskImage);
  return maskedImage;
}

predict(img.Image image) async //Predicts the image using the pretrained model
{
  print('predict()');
  print(imageTo3DList(image));

  List imageArr = imageTo3DList(image);
  List image2 = [];
  for(var i = 0; i < imageArr.shape[2]; i++)
    {
      var temp1 = [];
      for(var j = 0; j < imageArr.shape[0]; j++)
        {
          var temp2 = [];
          for(var k = 0; k < imageArr.shape[1]; k++)
            {
              temp2.add(imageArr[j][k][i].toDouble());
            }
          temp1.add(temp2);
        }
      image2.add(temp1);
    }
  print(image2.shape);

  Model customModel = await PyTorchMobile
      .loadModel('assets/saved_model.pt');
  var inputs = {"image": image, "height": imageArr.shape[0], "width": imageArr.shape[1]};
  print("INPUUUUTS");
  print(inputs);
 // List? prediction = await customModel
   //   .getPrediction([inputs], [3,800,800], DType.float32);
}
