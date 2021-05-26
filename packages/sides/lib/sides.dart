library sides;
import 'package:tflite/tflite.dart';
import 'dart:io';

predict(File? image) async
{
  String? res = await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false
  );




  var recognitions = await Tflite.runModelOnImage(
      path: image!.path,
      imageMean: 117.0,
      imageStd: 1.0,
      numResults: 5,
      threshold: 0.1,
      asynch: true
  );


  var result = recognitions![0]['label'] +","+ recognitions[0]['confidence'].toStringAsPrecision(3);


  return result;

}