import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sides/sides.dart';
import 'package:intl/intl.dart';

// import 'package:camera/camera.dart';
import 'package:flutter_better_camera/camera.dart';
import 'package:strings/strings.dart';
import 'package:image/image.dart' as ImagePackage;
import 'package:f_logs/f_logs.dart';

import 'package:path_provider/path_provider.dart';
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

  controllerInitialize(camera, ResolutionPreset res) {
    cameraStarted = true;
    controller = CameraController(
      camera,
      res,
      enableAudio: false,
      flashMode: FlashMode.off,
      // imageFormatGroup: ImageFormatGroup.yuv420,
    );
    initializeControllerFuture = controller.initialize();
  }
}

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

//All functions are in sides.dart -> packages/sides/lib/sides.dart

Future<void> main() async {
  await CameraInterface.camerasInitialize();
  await CarSides.loadAsset();
  // FLog.printLogs();
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
        // primarySwatch: Colors.orange,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
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
  Img? _imageFile;

  // Img? _croppedImage;
  List<CarSides>? _predictedSideList;
  late CarSides _predictedSide;
  late CarSides _realSide;

  late ImagePreviewPage _pictureScreen =
      new ImagePreviewPage(CameraInterface.cameras.first);

  int _selectedIndex = 0;
  PageController pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

//Take a picture
  Future getImage() async {
    print(_pictureScreen.cameraInterface.controller.flashMode);
    FLog.info(
        className: "MyHomePage",
        methodName: "getImage",
        text: "getImage() started");
    try {
      if (!_pictureScreen.cameraInterface.controller.value.isInitialized!) {
        FLog.warning(
            className: "MyHomePage",
            methodName: "getImage",
            text: "camera not initialized");
        return;
      } else {
        FLog.info(
            className: "MyHomePage",
            methodName: "getImage",
            text: "camera initialized");
      }
      // await _pictureScreen.cameraInterface.initializeControllerFuture;
      // XFile xImage =
      //     await _pictureScreen.cameraInterface.controller.takePicture();
      var cacheDir = await getTemporaryDirectory();

      var now = DateTime.now();
      var formatter = DateFormat('yyyyMMdd_HH_mm_ss');
      String currentTimeStamp = formatter.format(now);


      var path = cacheDir.path + "/" + currentTimeStamp;
      // var path = cacheDir.path + "/thumbnail.jpg";
      // if (await File(path).exists()) {
      //   print("file exist");
      //   File(path).delete();
      // }

      try {
        if (_pictureScreen.cameraInterface.controller.value.isTakingPicture!) {
          FLog.warning(
              className: "MyHomePage",
              methodName: "getImage",
              text: "camera is taking picture");
          return;
        }
        await _pictureScreen.cameraInterface.controller.takePicture(path);
      } catch (e) {
        FLog.error(
            className: "MyHomePage",
            methodName: "getImage takePicture()",
            text: "$e");
      }

      _imageFile = Img(path: path);
      await _imageFile!.initializationDone;
      FLog.info(
          className: "MyHomePage",
          methodName: "getImage",
          text: "image path: $path");
      // var cacheDir = await getTemporaryDirectory();
      // _croppedImage = _imageFile;
      // _croppedImage!.setPath('${cacheDir.path}/thumbnail.jpg');
      FLog.info(
          className: "MyHomePage",
          methodName: "getImage",
          text: "image resolution: ${_imageFile!.resolution}");

      if (_imageFile!.width < _imageFile!.height) {
        FLog.info(
            className: "MyHomePage",
            methodName: "getImage",
            text: "height > width");
        await _imageFile!.crop(0, (_imageFile!.height - _imageFile!.width) ~/ 2,
            _imageFile!.width, _imageFile!.width);
      } else {
        FLog.info(
            className: "MyHomePage",
            methodName: "getImage",
            text: "width > height");
        await _imageFile!.crop((_imageFile!.width - _imageFile!.height) ~/ 2, 0,
            _imageFile!.height, _imageFile!.height);
      }

      FLog.info(
          className: "MyHomePage",
          methodName: "getImage",
          text: "croppedImage resolution: ${_imageFile!.resolution}");

      await _imageFile!.resize(256, 256);

      _predictedSideList = await predict(_imageFile!.file!);
      _predictedSide = _predictedSideList![0];

      setState(() {
        _onItemTapped(1);
      });
      _realSide = await _showSingleChoiceDialog(context);
      print("RealSide: " + _realSide.label);

      FLog.info(
          className: "MyHomePage",
          methodName: "getImage",
          text: "realSide: $_realSide, predictedSide: $_predictedSide");

      // setState(() {});
      var uploaded = false;
      uploaded = await uploadImage(_imageFile!.file!, _predictedSide,
          _realSide); //TODO: Finish upload function in sides.dart
      if (uploaded == false) {
        await save(_imageFile!.file!, _predictedSide,
            _realSide); //Saves image with correct naming
      }
      await backup();

      File(path).delete();
    } catch (e) {
      FLog.error(className: "MyHomePage", methodName: "getImage", text: "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WillPopScope(
          onWillPop: () => Future.sync(onWillPop), child: buildPageView()),
      bottomNavigationBar: BottomNavigationBar(
        items: buildBottomNavBarItems(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _buttonFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  bool onWillPop() {
    if (pageController.page!.round() == pageController.initialPage)
      return true;
    else {
      pageController.previousPage(
        duration: Duration(milliseconds: 200),
        curve: Curves.linear,
      );
      return false;
    }
  }

  Widget buildPageView() {
    return PageView(
      controller: pageController,
      physics: NeverScrollableScrollPhysics(),
      onPageChanged: _pageChanged,
      children: <Widget>[
        _pictureScreen,
        ImageInfoPage(_imageFile, _predictedSideList),
        LogPage()
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
      BottomNavigationBarItem(
        icon: Icon(Icons.build),
        label: 'Logs',
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

class ImagePreviewPage extends StatefulWidget {
  final CameraDescription? camera;
  final CameraInterface cameraInterface = new CameraInterface();

  ImagePreviewPage(this.camera, {Key? key}) : super(key: key);

  controllerInitialize(ResolutionPreset res) =>
      cameraInterface.controllerInitialize(camera, res);

  @override
  ImagePreviewPageState createState() => ImagePreviewPageState();
}

class ImagePreviewPageState extends State<ImagePreviewPage>
    with WidgetsBindingObserver {
  ResolutionPreset resolution = ResolutionPreset.high;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FLog.info(
        className: "TakePictureScreenState",
        methodName: "AppState",
        text: "state changed to: $state");
    // FLog.info(className: "TakePictureScreenState", methodName: "AppState", text: "cameraStarted: ${widget.cameraInterface.cameraStarted}");
    if (!widget.cameraInterface.controller.value.isInitialized!) {
      FLog.info(
          className: "TakePictureScreenState",
          methodName: "AppState",
          text: "Controller not initialized");
      return;
    }
    if (state == AppLifecycleState.inactive) {
      FLog.info(
          className: "TakePictureScreenState",
          methodName: "AppState",
          text: "Dispose camera");
      widget.cameraInterface.controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      FLog.info(
          className: "TakePictureScreenState",
          methodName: "AppState",
          text: "Initialize camera");
      widget.controllerInitialize(resolution);
      widget.cameraInterface.initializeControllerFuture
          .then((value) => setState(() {}));
    }

    // if (!widget.cameraInterface.cameraStarted &&
    //     state == AppLifecycleState.resumed) {
    //   widget.controllerInitialize(resolution);
    //   FLog.info(
    //       className: "TakePictureScreenState",
    //       methodName: "AppState",
    //       text: "Initialize camera");
    //   widget.cameraInterface.cameraStarted = true;
    //   widget.cameraInterface.initializeControllerFuture
    //       .then((value) => setState(() {}));
    // } else if (widget.cameraInterface.cameraStarted) {
    //   FLog.info(
    //       className: "TakePictureScreenState",
    //       methodName: "AppState",
    //       text: "Dispose camera");
    //   widget.cameraInterface.controller.dispose();
    //   widget.cameraInterface.cameraStarted = false;
    // }
  }

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    // widget.cameraInterface.controller.dispose();
    // widget.cameraInterface.cameraStarted = false;
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    if (!widget.cameraInterface.cameraStarted) {
      if (width <= 365 && height < 600) {
        resolution = ResolutionPreset.medium;
        FLog.info(
            className: "TakePictureScreenState",
            methodName: "Build",
            text: "Camera resolution changed: $resolution");
      }
      widget.controllerInitialize(resolution);
    }

    return Container(
      color: Colors.black,
      child: FutureBuilder<void>(
        future: widget.cameraInterface.initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            try {
              return Stack(alignment: FractionalOffset.center, children: [
                Positioned.fill(
                    child: AspectRatio(
                        aspectRatio:
                            widget.cameraInterface.controller.value.aspectRatio,
                        child:
                            CameraPreview(widget.cameraInterface.controller))),
                Container(
                  width: width,
                  height: width,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 4),
                  ),
                ),
              ]);
            } catch (e) {
              FLog.error(
                  className: "TakePictureScreenState",
                  methodName: "Build",
                  text: "$e");
              return const Center(child: CircularProgressIndicator());
            }
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
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

  resetSide() {
    _currentSide = CarSides.sides[0];
  }
}

//Dialogue to ask for the real side
Future<CarSides> _showSingleChoiceDialog(BuildContext context) {
  SingleNotifier _singleNotifier = new SingleNotifier();
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
                            print(e);
                            if (value != _singleNotifier.currentSide) {
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
                  _singleNotifier.resetSide();
                },
              )
            ],
          ),
        );
      });
  return completer.future;
}

class ImageInfoPage extends StatelessWidget {
  final Img? image;
  final List<CarSides>? carSidesList;

  const ImageInfoPage(
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

  // void resizedImage()
  // {
  //   final img1 = ImagePackage.decodeImage(image!.file!.readAsBytesSync());
  //   final img3 = ImagePackage.copyCrop();
  //   final img2 = ImagePackage.copyResize(img1!, width: 240, height: 240);
  //   File('thumbnail.png').writeAsBytesSync(ImagePackage.encodePng(img2));
  //
  // }
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

class LogPage extends StatefulWidget {
  const LogPage({Key? key}) : super(key: key);

  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  LogLevel dropdownValue = LogLevel.ALL;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            DropdownButton(
              value: dropdownValue,
              onChanged: (LogLevel? newValue) {
                if (newValue != dropdownValue) {
                  setState(() {
                    dropdownValue = newValue!;
                  });
                }
              },
              items: [LogLevel.ALL, LogLevel.INFO, LogLevel.ERROR, LogLevel.WARNING]
                  .map((LogLevel value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
            ),
            ElevatedButton(
              child: Text('Clear Logs'),
              onPressed: () {
                setState(() {
                  FLog.clearLogs();
                });
              },
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder(
              future: FLog.getAllLogsByFilter(
                  logLevels: dropdownValue == LogLevel.ALL
                      ? []
                      : [dropdownValue.toString()]),
              builder:
                  (BuildContext context, AsyncSnapshot<List<Log>> snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Text(
                            "${snapshot.data![index].logLevel} ${snapshot.data![index].className} ${snapshot.data![index].methodName} ${snapshot.data![index].text!} ${snapshot.data![index].timestamp}",
                            style: TextStyle(fontSize: 18),
                          ),
                        );
                      });
                } else {
                  return Container();
                }
              }),
        ),
      ],
    );
  }
}
