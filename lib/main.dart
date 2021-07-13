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

  static late final List<CameraDescription> cameras;

  static camerasInitialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  }

  controllerInitialize(camera) {
    cameraStarted = true;
    controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    initializeControllerFuture = controller.initialize();
  }
}

class Img {
  File? file;
  ui.Image? uiImage;
  String? size;
  late Future _doneFuture;

  String? path;
  int? _originX;
  int? _originY;
  int? _cropWidth;
  int? _cropHeight;

  Img({this.path, this.file}) {
    if (path != null) {
      this.file = File(path!);
    }
    _doneFuture = init();
  }

  Img.fromCrop(this.path, this._originX, this._originY, this._cropWidth,
      this._cropHeight) {
    _doneFuture = init(crop: true);
  }

  Future init({crop = false}) async {
    if (crop) {
      await FlutterNativeImage.cropImage(
              path!, _originX!, _originY!, _cropWidth!, _cropHeight!)
          .then((value) => file = value);
    }
    await decodeImageFromList(file!.readAsBytesSync()).then((value) {
      this.uiImage = value;
    });
    await getFileSize(file!, 2).then((value) => this.size = value);
  }

  int get width => uiImage!.width;

  int get height => uiImage!.height;

  String get resolution => "$width" + "x" + "$height";

  String toString() {
    return resolution + " " + size!;
  }

  Future get initializationDone => _doneFuture;
}

//All functions are in sides.dart -> packages/sides/lib/sides.dart

Future<void> main() async {
  await CameraInterface.camerasInitialize();
  await CarSides.loadAsset();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SingleNotifier>(
          create: (_) => SingleNotifier(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  // final CameraDescription camera;

  MyApp({Key? key}) : super(key: key);

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
      home: MyHomePage('TF Car Sides'),
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

  // final CameraDescription camera;

  MyHomePage(this.title, {Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Img _imageFile;
  Img? _croppedImage;

  List<CarSides>? _predictedSideList;
  late CarSides _predictedSide;
  late CarSides _realSide;

  late TakePictureScreen _pictureScreen =
      new TakePictureScreen(CameraInterface.cameras.first);

  int _selectedIndex = 0;
  PageController pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

//Take a picture
  Future getImage() async {
    await _pictureScreen.cameraInterface.initializeControllerFuture;
    XFile xImage =
        await _pictureScreen.cameraInterface.controller.takePicture();
    _imageFile = Img(path: xImage.path);
    await _imageFile.initializationDone;
    print("img res: ${_imageFile.resolution}");
    _croppedImage = Img.fromCrop(
        _imageFile.file!.path,
        (_imageFile.uiImage!.height - _imageFile.uiImage!.width) ~/ 2,
        0,
        _imageFile.uiImage!.width,
        _imageFile.uiImage!.width);
    await _croppedImage!.initializationDone;

    _predictedSideList = await predict(_croppedImage!.file!);
    _predictedSide = _predictedSideList![0];

    setState(() {
      _onItemTapped(1);
    });
    _realSide = await _showSingleChoiceDialog(context);

    print("realSide: $_realSide");
    print("predictedSide: $_predictedSide");

    setState(() {});
    var uploaded = false;
    uploaded = await uploadImage(
        _croppedImage!.file!, _predictedSide, _realSide); //TODO: Finish upload function in sides.dart
    if(uploaded == false) {
      await save(_croppedImage!.file!, _predictedSide, _realSide); //Saves image with correct naming
    }
    await   backup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: buildPageView(),
      bottomNavigationBar: BottomNavigationBar(
        items: buildBottomNavBarItems(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      floatingActionButton: _buttonFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      onPageChanged: _pageChanged,
      children: <Widget>[
        _pictureScreen,
        DisplayPictureScreen(_croppedImage, _predictedSideList),
      ],
    );
  }

  void _pageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      pageController.animateToPage(index,
          duration: Duration(milliseconds: 500), curve: Curves.ease);
    });
  }

  List<BottomNavigationBarItem> buildBottomNavBarItems() {
    return [
      BottomNavigationBarItem(
        icon: Icon(Icons.camera),
        label: 'Camera',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.image),
        label: 'Image',
      ),
    ];
  }

  _buttonFAB() {
    if (_selectedIndex == 0)
      return FloatingActionButton(
          onPressed: getImage,
          tooltip: 'Pick Image',
          child: Icon(Icons.add_a_photo));
    else
      return null;
  }
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription? camera;
  final CameraInterface cameraInterface = new CameraInterface();

  TakePictureScreen(this.camera, {Key? key}) : super(key: key) {
    // controllerInitialize();
  }

  controllerInitialize() => cameraInterface.controllerInitialize(camera);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("state: $state");
    print("cameraStarted: ${widget.cameraInterface.cameraStarted}");
    if (!widget.cameraInterface.cameraStarted &&
        state == AppLifecycleState.resumed) {
      widget.controllerInitialize();
      print("Initialize camera");
      widget.cameraInterface.cameraStarted = true;
      widget.cameraInterface.initializeControllerFuture
          .then((value) => setState(() {}));
    } else if (widget.cameraInterface.cameraStarted) {
      print("Dispose camera");
      widget.cameraInterface.controller.dispose();
      widget.cameraInterface.cameraStarted = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    WidgetsBinding.instance!.addObserver(this);
    widget.controllerInitialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    widget.cameraInterface.controller.dispose();
    widget.cameraInterface.cameraStarted = false;
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    print("Device Width: $width, Height: $height");
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FutureBuilder<void>(
            future: widget.cameraInterface.initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Container(
                  width: width,
                  height: height,
                  child: CameraPreview(
                          widget.cameraInterface.controller),
                );
              } else {
                // Otherwise, display a loading indicator.
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 4),
            ),
          ),
        ],
      ),
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
Future<CarSides> _showSingleChoiceDialog(BuildContext context) {
  SingleNotifier _singleNotifier;
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
  final Img? image;
  final List<CarSides>? carSidesList;

  const DisplayPictureScreen(
    this.image,
    this.carSidesList, {
    Key? key,
  }) : super(key: key);

  List<Widget> description() {
    final TextStyle textStyle =
        TextStyle(color: Colors.white70, fontWeight: FontWeight.bold);
    List<Widget> widgetList = [];
    widgetList.add(Row(
      // mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text(
          image!.size!,
          style: textStyle,
        ),
        Spacer(),
        Text(
          image!.resolution,
          style: textStyle,
        )
      ],
    ));
    carSidesList!.forEach((element) => widgetList.add(Row(
          // mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              capitalize(element.label),
              style: textStyle,
            ),
            Spacer(),
            Text(
              element.confidenceToPercent(),
              style: textStyle,
            )
          ],
        )));
    return widgetList;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: Colors.black,
      child: image == null
          ? Icon(
              Icons.image_not_supported,
              color: Colors.white,
              size: 100,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.file(
                  image!.file!,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                  // alignment: Alignment.center,
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    // alignment: Alignment.bottomLeft,
                    width: MediaQuery.of(context).size.width / 2,
                    // height: 100,
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    margin: EdgeInsets.only(top: 10, left: 20),
                    decoration: BoxDecoration(
                      // color: Colors.white70,
                      borderRadius: BorderRadius.all(
                        Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      // mainAxisSize: MainAxisSize.max,
                      children: description(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
