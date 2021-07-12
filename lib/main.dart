import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sides/sides.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

//Possible classes
final List<String> sides = ['Front', 'Back', 'Left', 'Right', 'Diagonal'];
String realSide = "";
var firstCamera;

//All functions are in sides.dart -> packages/sides/lib/sides.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  firstCamera = cameras.first;

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<SingleNotifier>(
        create: (_) => SingleNotifier(),
      )
    ],
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TF Car Sides',
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
      home: MyHomePage(title: 'Car Sides', camera: firstCamera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title, required this.camera})
      : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final CameraDescription camera;
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class SingleNotifier extends ChangeNotifier {
  var _currentSide = sides[0];

  SingleNotifier();

  String get currentSide => _currentSide;

  updateSide(var value) {
    if (value != _currentSide) {
      _currentSide = value;
      notifyListeners();
    }
  }
}

//Dialogue to ask for the real side
_showSingleChoiceDialog(BuildContext context, SingleNotifier _singleNotifier) =>
    showDialog(
        context: context,
        builder: (context) {
          _singleNotifier = new SingleNotifier();
          _singleNotifier = Provider.of<SingleNotifier>(context);
          realSide = _singleNotifier.currentSide;
          return AlertDialog(
            title: Text("Select the real side!"),
            content: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sides
                      .map((e) => RadioListTile(
                    title: Text(e),
                    value: e,
                    groupValue: _singleNotifier.currentSide,
                    selected: _singleNotifier.currentSide == e,
                    onChanged: (value) {
                      print("onchange: ");
                      print(value);
                      print(_singleNotifier.currentSide);

                      if (value != _singleNotifier.currentSide) {
                        print(value);
                        _singleNotifier.updateSide(value);
                        print(_singleNotifier.currentSide);
                        //Navigator.of(context).pop();
                      }
                    },
                  ))
                      .toList(),
                ),
              ),
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text("OK"),
                onPressed: () {
                  //_singleNotifier.updateSide(realSide);
                  realSide = _singleNotifier.currentSide;
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  final picker = ImagePicker();
  var recognitions;
  var res = "";
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState()  {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

//Take a picture
  Future getImage() async {
    await _initializeControllerFuture;
    final image = await _controller.takePicture();
    _image = File(image.path);
    res = await predict(_image); //Predict using model
    print(res);
    SingleNotifier real = new SingleNotifier();
    await _showSingleChoiceDialog(context, real);
    print(realSide); //Get real class from the dialogue
    var uploaded = false;
    uploaded = await uploadImage(
        _image, res, realSide); //TODO: Finish upload function in sides.dart
    if(uploaded == false) {
      await save(_image, res, realSide); //Saves image with correct naming
    }
    await backup();

    // setState(() {
    //   if (pickedFile != null) {
    //     _image = File(pickedFile.path);
    //   } else {
    //     print('No image selected.');
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Picker Example'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.add_a_photo),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}
