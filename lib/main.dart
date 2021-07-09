import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';
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
        ResolutionPreset.medium,
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

class Img {
  final File file;
  ui.Image? uiImage;
  String? size;

  int get width => uiImage!.width;

  int get height => uiImage!.height;

  String get resolution => "$width" + "x" + "$height";

  String toString() {
    return resolution + " " + size!;
  }

  Img(this.file, [this.uiImage, this.size]);
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late File _imageFile;
  late Img _croppedImage;

  List<CarSides>? _predictedSideList;
  late CarSides _predictedSide;
  late CarSides _realSide;

  bool _pictureButtonActive = false;
  double bottomSheetHeight = 68;

  late TakePictureScreen _pictureScreen = new TakePictureScreen(widget.camera);
  final SingleNotifier _singleNotifier = new SingleNotifier();

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
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Widget createText() {
    final textStyle = TextStyle(fontSize: 20);
    List<Widget> textList = [];
    textList.add(Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            textStyle: TextStyle(fontSize: 20),
            padding: EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: _pictureButtonActive ? showImage : null,
          child: const Text('Show picture'),
        ),
        Spacer(),
        TextButton(
          style: TextButton.styleFrom(
            textStyle: TextStyle(fontSize: 20),
            padding: EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: getImage,
          child: const Text('Take picture'),
        )
      ],
    ));
    if (_predictedSideList != null)
      _predictedSideList!.forEach((element) {
        textList.add(Divider());
        textList.add(Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              capitalize(element.label),
              style: textStyle,
            ),
            Spacer(),
            Text(
              element.confidenceToPercent(),
              style: textStyle,
            ),
          ],
        ));
      });
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: Column(children: textList));
  }

//Take a picture
  Future getImage() async {
    await _pictureScreen.cameraInterface.initializeControllerFuture;
    XFile xImage =
        await _pictureScreen.cameraInterface.controller.takePicture();
    _imageFile = File(xImage.path);
    getFileSize(_imageFile, 2).then((value) => print("Picture size: $value"));

    var decodedImage = await decodeImageFromList(_imageFile.readAsBytesSync());
    // print("Picture resolution: ${decodedImage.height}x${decodedImage.width}");

    _croppedImage = Img(await FlutterNativeImage.cropImage(
        _imageFile.path, 0, 0, decodedImage.width, decodedImage.width));
    _croppedImage.uiImage =
        await decodeImageFromList(_croppedImage.file.readAsBytesSync());
    _croppedImage.size = await getFileSize(_imageFile, 2);
    _predictedSideList = await predict(_croppedImage.file);
    _predictedSide = _predictedSideList![0];

    showImage();
    _realSide = await _showSingleChoiceDialog(context, _singleNotifier);

    print("realSide: $_realSide");
    print("predictedSide: $_predictedSide");

    setState(() {
      bottomSheetHeight = _predictedSideList!.length * 39 + 68;
    });
    uploadImage(_croppedImage.file, _predictedSide, _realSide);
    save(_croppedImage.file, _predictedSide,
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
      body: Stack(
        children: [
          _pictureScreen,
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 4),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: width,
              height: bottomSheetHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.white),
                ],
              ),
              child: createText(),
            ),
          ),
        ],
      ),
    );
  }

  showImage({File? imageFile, CarSides? carSide, String? extraText}) async {
    if (carSide == null) carSide = _predictedSide;

    if (imageFile == null) imageFile = _croppedImage.file;

    if (extraText == null) extraText = _croppedImage.toString();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DisplayPictureScreen(
// Pass the automatically generated path to
// the DisplayPictureScreen widget.
          imageFile!,
          carSide.toString(),
          text: extraText,
        ),
      ),
    );
  }

  List<Widget> predictionListWidget() {
    List<Widget> widgetsList = [];
    _predictedSideList!
        .forEach((element) => widgetsList.add(Text(element.label)));
    return widgetsList;
  }
}

createTexttextfields(int d) {
  var textEditingControllers = <TextEditingController>[];

  var textFields = <TextField>[];
  var list = new List<int>.generate(d, (i) => i + 1);
  print(list);

  list.forEach((i) {
    var textEditingController = new TextEditingController(text: "test $i");
    textEditingControllers.add(textEditingController);
    return textFields.add(new TextField(controller: textEditingController));
  });
  return textFields;
}

class DraggableSheet extends StatefulWidget {
  final double _initialChildSize;
  final double _minChildSize;
  final double _maxChildSize;
  final List<CarSides>? _predictedSideList;
  final bool _pictureButtonActive;
  final Function() _showImage;

  DraggableSheet(this._initialChildSize, this._minChildSize, this._maxChildSize,
      this._predictedSideList, this._pictureButtonActive, this._showImage);

  _DraggableSheetState createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet> {
  @override
  Widget build(BuildContext context) {
    setState(() {});
    print(
        "initial: ${widget._initialChildSize}, min: ${widget._minChildSize}, max: ${widget._maxChildSize}");
    return new DraggableScrollableSheet(
      initialChildSize: widget._initialChildSize,
      minChildSize: widget._minChildSize,
      maxChildSize: widget._maxChildSize,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          color: Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            controller: scrollController,
            itemCount: widget._predictedSideList == null
                ? 1
                : widget._predictedSideList!.length + 1,
            itemBuilder: (BuildContext context, int index) {
              final textStyle = TextStyle(fontSize: 20);
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      textStyle: textStyle,
                    ),
                    onPressed:
                        widget._pictureButtonActive ? widget._showImage : null,
                    child: const Text('Show picture'),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      capitalize(widget._predictedSideList![index - 1].label),
                      style: textStyle,
                    ),
                    Spacer(),
                    Text(
                      widget._predictedSideList![index - 1]
                          .confidenceToPercent(),
                      style: textStyle,
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(),
          ),
        );
      },
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
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    widget.cameraInterface.controllerInitialize(widget.camera);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    widget.cameraInterface.controller.dispose();
    widget.cameraInterface.cameraStarted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
  final String? text;

  const DisplayPictureScreen(
    this.image,
    this.title, {
    this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(
              image,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              alignment: Alignment.center,
            ),
            Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.all(
                    Radius.circular(20),
                  ),
                ),
                child: text != null
                    ? Text(
                        text!,
                        // style: TextStyle(color: Colors.white),
                      )
                    : null),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
