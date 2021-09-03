import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sides/sides.dart';
import 'package:strings/strings.dart';
import 'package:f_logs/f_logs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as ImagePackage;
import 'dart:typed_data';

//All functions are in sides.dart -> packages/sides/lib/sides.dart

Future<void> main() async {
  // await CameraInterface.camerasInitialize();
  // await CarSides.loadAsset();
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
  String? filename;
  String imageName = 'car_1024_1024.jpg';
  int _selectedIndex = 0;
  PageController pageController = PageController(
    initialPage: 0,
    keepPage: true,
  );

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load('assets/$path');

    final file = File('${(await getTemporaryDirectory()).path}/$path');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
  }

//Take a picture
  Future getImage() async {
    print('getImage');
    ByteData imageData = await rootBundle.load('assets/car_1024_1024.jpg');
    List<int> bytes = Uint8List.view(imageData.buffer);
    ImagePackage.Image image = ImagePackage.decodeImage(bytes)!;
    // var image = ImagePackage.decodeJpg((await getImageFileFromAssets(imageName)).readAsBytesSync());
    filename = await predict(image);
    setState(() {
      _onItemTapped(1);
    });
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
        Image(image: AssetImage('assets/$imageName')),
        MrcnnPage(filename),
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

class MrcnnPage extends StatelessWidget {
  final String? filename;

  const MrcnnPage(this.filename, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: filename == null ? null : Image.file(File(filename!)),
    );
  }
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
              items: [
                LogLevel.ALL,
                LogLevel.INFO,
                LogLevel.ERROR,
                LogLevel.WARNING
              ].map((LogLevel value) {
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
