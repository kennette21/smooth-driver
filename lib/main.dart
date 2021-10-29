import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'package:wakelock/wakelock.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
// import 'package:localstore/localstore.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smooth Driving',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Smooth Drivng Helper'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class AccDataPoint {
  String time;
  double x;
  double y;
  double z;

  AccDataPoint({
    this.time,
    this.x,
    this.y,
    this.z,
  });

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'x': x,
      'y': y,
      'z': z
    };
  }

  factory AccDataPoint.fromAccData(String time, List<double> accData) {
    return AccDataPoint(
      time: time,
      x: accData[0],
      y: accData[1],
      z: accData[2],
    );
  }

  factory AccDataPoint.fromMap(Map<String, dynamic> map) {
    return AccDataPoint(
      time: map['time'],
      x: map['x'],
      y: map['y'],
      z: map['z'],
    );
  }
}

/// todo: should include saving on the objecT? lets see...
// extension ExtAccDataPoint on AccDataPoint {
//   Future save() async {
//     final _db = Localstore.instance;
//     return _db.collection('recordings').doc(curRec).set(toMap());
//   }
//
//   Future delete() async {
//     final _db = Localstore.instance;
//     return _db.collection('recordings').doc(id).delete();
//   }
// }

class _MyHomePageState extends State<MyHomePage> {
  final _items = <String, AccDataPoint>{};

  List<String> _recordings;

  int _selectedIndex = 0;
  bool _isRecording = false;
  File curRecordingFile;
  List recordingFiles = [];
  File selectedFile;
  List<dynamic> selectedFileData;

  List<double> _userAccelerometerValues;
  double _currentSliderValue = 0;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> _localFile (String name) async {
    final path = await _localPath;
    print('find the file at: ' + path);
    return File('$path/$name.json');
  }

  // Future<int> readCounter() async {
  //   try {
  //     final files = ;
  //
  //     // Read the file
  //     final contents = await file.readAsString();
  //
  //     return int.parse(contents);
  //   } catch (e) {
  //     // If encountering an error, return 0
  //     return 0;
  //   }
  // }

  void _onItemTapped(int index) async {
    String dir = await _localPath;
    setState(() {
      _selectedIndex = index;
      recordingFiles = Directory(dir).listSync();
      selectedFile = null;
    });
    print(recordingFiles);
  }

  calculateColor(double v) {
    // todo: make this more clean, probably extract the acc value calculation to a separate method?
    MaterialColor color = Colors.green;
    if (1 * (_currentSliderValue / 100) <= v &&
        v <= 3 * (_currentSliderValue / 100)) {
      color = Colors.amber;
    } else if (v >= 3 * (_currentSliderValue / 100)) {
      color = Colors.red;
    }
    return color;
  }

  calculateSize() {
    // todo: make much more sopphisticated this is very dumb now
    var v = _userAccelerometerValues.reduce((a, b) => a + b) / 3;
    double size = 100;
    if (1 * (_currentSliderValue / 100) <= v &&
        v <= 3 * (_currentSliderValue / 100)) {
      size = 200;
    } else if (v >= 3 * (_currentSliderValue / 100)) {
      size = 400;
    }
    return size;
  }

  final Map<int, String> idxCoorMap = {0: "X", 1: "Y", 2: "Z"};

  Text generateText(int idx) {
    return Text(
      '${idxCoorMap[idx]}: ${_userAccelerometerValues[idx].abs().toStringAsFixed(2)}',
      style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 32,
          color: calculateColor(_userAccelerometerValues[idx].abs())),
    );
  }

  toggleRecording() async {
    if (_isRecording) {
      // add closing ]
      curRecordingFile.writeAsString('{}]',mode: FileMode.append);
      // writing to the current file
      curRecordingFile = null;
    } else {
      // create a new file to record to
      curRecordingFile = await _localFile(DateTime.now().toString());
      // add starting [
      curRecordingFile.writeAsString('[',mode: FileMode.append);
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void selectFile(File maybeFile) async {
    String contents = await maybeFile.readAsString();
    List<dynamic> fileData = json.decode(contents);
    // print("just one");
    // print(contents);
    setState(() {
      selectedFile = maybeFile;
      selectedFileData = fileData;
    });
  }

  Center chartBody() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(10),
        width: double.infinity,
        child: LineChart(LineChartData(
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                  spots: selectedFileData.asMap().map((i, elem) {
                    print(elem);
                    if (elem['x'] != null) {
                      return MapEntry(i, FlSpot(i.toDouble(),elem['x']));
                    } else {
                      return MapEntry(i, FlSpot(0.0, 0.0));
                    }
                  }).values.toList()
              )
            ]
        ),
        ),
      ),
    );
  }

  Center historyBody(){
    return selectedFile != null ? chartBody() : Center(
      child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: recordingFiles.length,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              height: 50,
              child: GestureDetector(
                  child: Center(child: Text('Entry ${recordingFiles[index]}')),
                  onTap: () => selectFile(recordingFiles[index])
              ),
            );
          }
      )
    );
  }

  Center liveBody() {
    return Center(
    // Center is a layout widget. It takes a single child and positions it
    // in the middle of the parent.
    child: Column(
      // Column is also a layout widget. It takes a list of children and
      // arranges them vertically. By default, it sizes itself to fit its
      // children horizontally, and tries to be as tall as its parent.
      //
      // Invoke "debug painting" (press "p" in the console, choose the
      // "Toggle Debug Paint" action from the Flutter Inspector in Android
      // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
      // to see the wireframe for each widget.
      //
      // Column has various properties to control how it sizes itself and
      // how it positions its children. Here we use mainAxisAlignment to
      // center the children vertically; the main axis here is the vertical
      // axis because Columns are vertical (the cross axis would be
      // horizontal).
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
            width: 400,
            height: 400,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                width: 300,
                height: calculateSize(),
                decoration: new BoxDecoration(
                  color: calculateColor(
                      _userAccelerometerValues.reduce((a, b) => a + b) / 3),
                  shape: BoxShape.rectangle,
                ),
                duration: const Duration(milliseconds: 700),
                // Provide an optional curve to make the animation feel smoother.
                curve: Curves.fastOutSlowIn,
              ),
            )),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              generateText(0),
              generateText(1),
              generateText(2),
            ],
          ),
        ),
        Slider(
          value: _currentSliderValue,
          min: 0,
          max: 100,
          divisions: 5,
          label: _currentSliderValue.round().toString(),
          onChanged: (double value) {
            setState(() {
              _currentSliderValue = value;
            });
          },
        ),
      ],
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final userAccelerometer =
        _userAccelerometerValues?.map((double v) => v.toStringAsFixed(1));

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: _selectedIndex == 0 ? liveBody() : historyBody()
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_graph),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: toggleRecording,
          child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record_sharp),
          backgroundColor: _isRecording ? Colors.blue : Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  @override
  void dispose() {
    super.dispose();
    Wakelock.disable();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    Wakelock.enable();
    super.initState();
    _streamSubscriptions.add(
      userAccelerometerEvents.listen(
        (UserAccelerometerEvent event) {
          List<double> accData = [event.x, event.y, event.z];
          setState(() {
            _userAccelerometerValues = accData;
          });
          if (_isRecording) {
            // write to the current file
            print("writing to file");
            final now = DateTime.now();
            final accDataPoint = AccDataPoint.fromAccData(now.toString(), accData);
            print(accDataPoint);
            print(accDataPoint.toMap());
            print(json.encode(accDataPoint.toMap()));
            curRecordingFile.writeAsString('${json.encode(accDataPoint.toMap())},',mode: FileMode.append);
            // final id = _db.collection('recordings').doc(curRecordingId).collection(item.time.toString()).doc().id;
            // _db.collection('recordings').doc(curRecordingId).collection(item.time.toString()).doc(id).set(item.toMap());
          }
        },
      ),
    );
  }
}
