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

class _MyHomePageState extends State<MyHomePage> {
  late File _imageFile;
  Img? _croppedImage;

  List<CarSides>? _predictedSideList;
  late CarSides _predictedSide;
  late CarSides _realSide;

  late TakePictureScreen _pictureScreen = new TakePictureScreen(widget.camera);
  final SingleNotifier _singleNotifier = new SingleNotifier();

  int _selectedIndex = 0;
  PageController pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

//Take a picture
  Future getImage() async {
    print(
        "resolution ${_pictureScreen.cameraInterface.controller.resolutionPreset}");
    await _pictureScreen.cameraInterface.initializeControllerFuture;
    XFile xImage =
        await _pictureScreen.cameraInterface.controller.takePicture();
    _imageFile = File(xImage.path);
    getFileSize(_imageFile, 2).then((value) => print("Picture size: $value"));

    var decodedImage = await decodeImageFromList(_imageFile.readAsBytesSync());
    print("Picture resolution: ${decodedImage.height}x${decodedImage.width}");

    _croppedImage = Img(await FlutterNativeImage.cropImage(
        _imageFile.path, (decodedImage.height - decodedImage.width) ~/ 2, 0, decodedImage.width, decodedImage.width));
    _croppedImage!.uiImage =
        await decodeImageFromList(_croppedImage!.file.readAsBytesSync());
    _croppedImage!.size = await getFileSize(_imageFile, 2);
    _predictedSideList = await predict(_croppedImage!.file);
    _predictedSide = _predictedSideList![0];

    setState(() {
      _onItemTapped(1);
    });
    _realSide = await _showSingleChoiceDialog(context, _singleNotifier);

    print("realSide: $_realSide");
    print("predictedSide: $_predictedSide");

    setState(() {});

    var uploaded = false;
    uploaded = await uploadImage(
        _croppedImage!.file, _predictedSide, _realSide); //TODO: Finish upload function in sides.dart
    if(uploaded == false) {
      await save(_croppedImage!.file, _predictedSide, _realSide); //Saves image with correct naming
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
                // If the Future is complete, display the preview.
                return CameraPreview(widget.cameraInterface.controller);
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
  final Img? image;
  final List<CarSides>? carSidesList;

  const DisplayPictureScreen(
    this.image,
    this.carSidesList, {
    Key? key,
  }) : super(key: key);

  List<Widget> description() {
    List<Widget> widgetList = [];
    widgetList.add(Text(image.toString()));
    carSidesList!
        .forEach((element) => widgetList.add(Text(element.toString())));
    return widgetList;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image != null)
            Image.file(
              image!.file,
              // fit: BoxFit.fitWidth,
              // width: double.infinity,
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
            child: Column(
              children: description(),
            ),
          ),
        ],
      ),
    );
  }
}
