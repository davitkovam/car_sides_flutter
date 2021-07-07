import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sides/sides.dart';
import 'package:camera/camera.dart';
import 'package:strings/strings.dart';
import 'package:flutter_native_image/flutter_native_image.dart';

//Possible classes

class CameraInterface {
  late CameraController controller;
  late Future<void> initializeControllerFuture;
  late bool cameraStarted = false;

  controllerInitialize(camera) {
    cameraStarted = true;
    controller = CameraController(
        // Get a specific camera from the list of available cameras.
        camera,
        // Define the resolution to use.
        ResolutionPreset.veryHigh,
        enableAudio: false);

    // Next, initialize the controller. This returns a Future.
    initializeControllerFuture = controller.initialize();
  }
}
//All functions are in sides.dart -> packages/sides/lib/sides.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  await CarSides.loadAsset();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SingleNotifier>(
          create: (_) => SingleNotifier(),
        ),
      ],
      child: MyApp(cameras.first),
    ),
  );
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  final CameraDescription camera;

  MyApp(this.camera, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.orange,
      ),
      home: MyHomePage('TF Car Sides', camera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final String title;
  final CameraDescription camera;

  MyHomePage(this.title, this.camera, {Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late File _imageFile;
  late File _croppedImageFile;

  late CarSides _predictedSide;
  late List<CarSides> _predictedSideList;
  late CarSides _realSide;

  late TakePictureScreen _pictureScreen = new TakePictureScreen(widget.camera);
  final SingleNotifier _singleNotifier = new SingleNotifier();
  String _predictionText = "Take picture first";

  bool _showPictureButton = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("state: $state");
    if (!_pictureScreen.cameraInterface.cameraStarted &&
        state == AppLifecycleState.resumed) {
      print("Initialize camera");
      _pictureScreen = new TakePictureScreen(widget.camera);
      _pictureScreen.controllerInitialize();
      _pictureScreen.cameraInterface.cameraStarted = true;
    } else if (_pictureScreen.cameraInterface.cameraStarted) {
      print("Dispose camera");
      _pictureScreen.cameraInterface.controller.dispose();
      _pictureScreen.cameraInterface.cameraStarted = false;
    }
    _pictureScreen.cameraInterface.initializeControllerFuture
        .then((value) => setState(() {}));
  }

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    print("HomePage dispose");
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

//Take a picture
  Future getImage() async {
    await _pictureScreen.cameraInterface.initializeControllerFuture;
    XFile xImage =
        await _pictureScreen.cameraInterface.controller.takePicture();
    _imageFile = File(xImage.path);
    getFileSize(_imageFile, 2).then((value) => print("Picture size: $value"));

    var decodedImage = await decodeImageFromList(_imageFile.readAsBytesSync());
    print("Picture resolution: ${decodedImage.height}x${decodedImage.width}");

    _croppedImageFile = await FlutterNativeImage.cropImage(
        _imageFile.path, 0, 0, decodedImage.width, decodedImage.width);
    _predictedSideList = await predict(_croppedImageFile);
    _predictedSide = _predictedSideList[0];

    showImage(extraText: "${decodedImage.height}x${decodedImage.width}");
    _realSide = await _showSingleChoiceDialog(context, _singleNotifier);

    // List<CarSides> completeList;
    // completeList = await Future.wait([
    //   _showSingleChoiceDialog(context, _singleNotifier),
    //   predict(_imageFile).then((value) => showImage(_croppedImageFile, carSide: value))
    // ]);
    // _realSide = completeList[0];
    // _predictedSide = completeList[1];

    print("realSide: $_realSide");
    print("predictedSide: $_predictedSide");

    setState(() {
      _predictionText = "Model result: $_predictedSideList";
      _showPictureButton = true;
    });
    uploadImage(_croppedImageFile, _predictedSide, _realSide);
    save(_croppedImageFile, _predictedSide,
        _realSide); //Saves image with correct naming
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    print("Device Width: $width, Height: $height");
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // body: Stack(
      //   children: <Widget>[
      //     _pictureScreen,
      //     Column(
      //       children: [
      //         Container(
      //             width: width,
      //             height: width,
      //             decoration: BoxDecoration(
      //                 border: Border.all(color: Colors.greenAccent, width: 4))),
      //         DraggableScrollableSheet(
      //           builder: (context, controller) => Container(
      //             height: height,
      //             color: Colors.white70,
      //             child: ListView.builder(
      //               controller: controller,
      //               itemCount: _predictedSideList.length,
      //               itemBuilder: (context, index) {
      //                 final side = _predictedSideList[index];
      //                 return ListTile(
      //                   title: Text(
      //                     side.label,
      //                     style: TextStyle(fontSize: 24),
      //                   ),
      //                 );
      //               },
      //             ),
      //           ),
      //         ),
      //       ],
      //     ),
      //   ],
      // ),
      body: Stack(
        children: <Widget>[
          _pictureScreen,
          Column(
            children: [
              Container(
                width: width,
                height: width,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 4),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.white),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _predictionText,
                        style: TextStyle(fontSize: 20),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 20),
                        ),
                        onPressed: _showPictureButton ? showImage : null,
                        child: const Text('Show picture'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.add_a_photo),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(
//       title: Text(widget.title),
//     ),
//     body: Column(children: [_pictureScreen, Text("Babushka")]),
//     floatingActionButton: FloatingActionButton(
//       onPressed: getImage,
//       tooltip: 'Pick Image',
//       child: Icon(Icons.add_a_photo),
//     ),
//     floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
//   );
// }

  showImage({File? imageFile, CarSides? carSide, String? extraText}) async {
    if (carSide == null) {
      carSide = _predictedSide;
    }
    if (imageFile == null) {
      imageFile = _croppedImageFile;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DisplayPictureScreen(
// Pass the automatically generated path to
// the DisplayPictureScreen widget.
          imageFile!,
          extraText == null
              ? carSide.toString()
              : carSide.toString() + ' ' + extraText,
        ),
      ),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final CameraInterface cameraInterface = new CameraInterface();

  TakePictureScreen(this.camera, {Key? key}) : super(key: key);

  controllerInitialize() => cameraInterface.controllerInitialize(camera);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  @override
  void initState() {
    print("TakePictureScreen initState()");
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    widget.cameraInterface.controllerInitialize(widget.camera);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    print("Camera dispose");
    widget.cameraInterface.controller.dispose();
    widget.cameraInterface.cameraStarted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        "Camera build, cameraStarted: ${widget.cameraInterface.cameraStarted}");
    return FutureBuilder<void>(
      future: widget.cameraInterface.initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the Future is complete, display the preview.
          return CameraPreview(widget.cameraInterface.controller);
        } else {
          // Otherwise, display a loading indicator.
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

// @override
// Widget build(BuildContext context) {
//   return FutureBuilder<void>(
//     future: widget.cameraInterface.initializeControllerFuture,
//     builder: (context, snapshot) {
//       if (snapshot.connectionState == ConnectionState.done) {
//         // If the Future is complete, display the preview.
//         return CameraPreview(widget.cameraInterface.controller);
//       } else {
//         // Otherwise, display a loading indicator.
//         return const Center(child: CircularProgressIndicator());
//       }
//     },
//   );
// }
}

class SingleNotifier extends ChangeNotifier {
  late String _currentSide;

  SingleNotifier() {
    _currentSide = CarSides.sides[0];
  }

  String get currentSide => _currentSide;

  updateSide(var value) {
    if (value != _currentSide) {
      _currentSide = value;
      notifyListeners();
    }
  }
}

//Dialogue to ask for the real side
Future<CarSides> _showSingleChoiceDialog(
    BuildContext context, SingleNotifier _singleNotifier) {
  final completer = new Completer<CarSides>();
  showDialog(
      context: context,
      builder: (context) {
        _singleNotifier = Provider.of<SingleNotifier>(context);
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Text("Select the real side!"),
            content: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: CarSides.sides
                      .map(
                        (e) => RadioListTile(
                          title: Text(capitalize(e)),
                          value: e,
                          groupValue: _singleNotifier.currentSide,
                          selected: _singleNotifier.currentSide == e,
                          onChanged: (value) {
                            if (value != _singleNotifier.currentSide) {
                              print(
                                  "onChange: from ${_singleNotifier.currentSide} to $value");
                              _singleNotifier.updateSide(value);
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: <Widget>[
              new TextButton(
                child: new Text("OK"),
                onPressed: () {
                  completer.complete(CarSides(_singleNotifier._currentSide));
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        );
      });
  return completer.future;
}

class DisplayPictureScreen extends StatelessWidget {
  final File image;
  final String title;

  const DisplayPictureScreen(
    this.image,
    this.title, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(
        image,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      ),
      backgroundColor: Colors.black,
    );
  }
}
