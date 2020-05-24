import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class ColorLed {
  bool isOn;
  int red;
  int green;
  int blue;
  int alpha;
  Color color;
  ColorLed({this.isOn,this.red,this.green,this.blue,this.alpha,this.color});
  factory ColorLed.fromJson(Map<String,dynamic> parsedJson) {
    return ColorLed(
      isOn: parsedJson["isOn"],
      red: parsedJson["red"],
      green: parsedJson["green"],
      blue: parsedJson["blue"],
      alpha: parsedJson["alpha"],
      color: new Color.fromARGB(parsedJson["alpha"], parsedJson["red"], parsedJson["green"], parsedJson["blue"])
    );
  }
  Map<String,dynamic> toJson() {
    return {
      "isOn": this.isOn,
      "red" : this.red,
      "green" : this.green,
      "blue" : this.blue,
      "alpha" : this.alpha
    };
  }
}


class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);
  @override
  _MyHomePageState createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {

  String BLE_NAME = "ESP32-led-strip-beb5483e";
  String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  String CHARACT_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  String CHARACT_UUID_TX = "beb5483e-36e1-4688-b7f5-c5c9c331914b";

  ColorLed _colorLed;
  bool lightTheme = true;
  
  BleManager _bleManager = new BleManager();
  Peripheral _esp;
  StreamSubscription<ScanResult> _scanSubstriction;
  StreamSubscription<Uint8List> _streamNotification;
  Characteristic _characteristic;
  Characteristic _characteristicTX;

  @override
  void initState() {
    super.initState();
    _bleManager.createClient().then((value) => _connectToEsp());
  }
  
  _connectToEsp() {
    _scanSubstriction = _bleManager.startPeripheralScan().listen((ScanResult scanResult) {
      print('*** START SCAN');
      print(scanResult.peripheral.name);
      if (scanResult.peripheral.name == BLE_NAME) {
        scanResult.peripheral.connect().then((value) async {
          print("esp connected..");
          _bleManager.stopPeripheralScan();
          setState(() {
            _esp = scanResult.peripheral;
          });
          print(_esp.toString());
          _esp.discoverAllServicesAndCharacteristics().then((value) {
            _esp.characteristics(SERVICE_UUID).then((characteristics) {
              print('search char');
              for (Characteristic characteristic in characteristics) {
                // Char read/write
                if (characteristic.uuid == CHARACT_UUID) {
                  print('char finded');
                  setState(() {
                    _characteristic = characteristic;
                  });
                  _characteristic.read().then((value) {
                    Map<String,dynamic> response = json.decode(utf8.decode(value));
                    setState(() {
                      _colorLed = new ColorLed.fromJson(response);
                    });
                  });
                }
                // Char notification
                if (characteristic.uuid == CHARACT_UUID_TX) {
                  print('charTX finded');
                  setState(() {
                    _characteristicTX = characteristic;
                  });
                  _streamNotification = characteristic.monitor().listen((value) {
                    print(value);
                    Map<String,dynamic> response = json.decode(utf8.decode(value));
                    setState(() {
                      _colorLed = new ColorLed.fromJson(response);
                    });
                  });
                }
              }
            }).catchError((e) {
              print(e);
            });
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _esp.disconnectOrCancelConnection();
    super.dispose();
  }
  
  
  @override
  Widget build(BuildContext context) {
    return (_colorLed == null) ? _bodyUnconnected() : _bodyConnected();
  }

  Widget _bodyUnconnected() {
    return Center(
      child: CircularProgressIndicator()
    );
  }

  Widget _bodyConnected() {
    return Theme(
        data: lightTheme ? ThemeData.light() : ThemeData.dark(),
        child: Scaffold(
            appBar: AppBar(
              title: GestureDetector(
                child: Text('Flutter Color Picker Example'),
                onDoubleTap: () => setState(() => lightTheme = !lightTheme),
              ),
              actions: <Widget>[
                IconButton(
                  icon: Icon(Icons.bluetooth, color: Colors.white),
                  onPressed: () {
                    //
                  },
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(_esp.toString()),
                        Text(_characteristic.toString()),
                        Text(_colorLed.toJson().toString()),
                      ],
                    ),
                  ),

                  Switch(
                    value: _colorLed.isOn,
                    onChanged: (value) {
                      setState(() {
                        _colorLed.isOn = value;
                      });
                      _sendColor();
                    }
                  ),
                  RaisedButton(
                    elevation: 3.0,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            titlePadding: const EdgeInsets.all(0.0),
                            contentPadding: const EdgeInsets.all(0.0),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: _colorLed.color,
                                onColorChanged: changeColor,
                                colorPickerWidth: 300.0,
                                pickerAreaHeightPercent: 0.7,
                                enableAlpha: true,
                                displayThumbColor: true,
                                showLabel: true,
                                paletteType: PaletteType.hsv,
                                pickerAreaBorderRadius: const BorderRadius.only(
                                  topLeft: const Radius.circular(2.0),
                                  topRight: const Radius.circular(2.0),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('Change me'),
                    color: _colorLed.color,
                    textColor: useWhiteForeground(_colorLed.color)
                        ? const Color(0xffffffff)
                        : const Color(0xff000000),
                  ),
                  RaisedButton(
                    child: Text("Send"),
                    onPressed: () => _sendColor(),
                  )
                ],
              ),
            )
        )
    );
  }

  void changeColor(Color color) {
    if (color != _colorLed.color) {
      setState(() {
        _colorLed.color = color;
        _colorLed.red = color.red;
        _colorLed.green = color.green;
        _colorLed.blue = color.blue;
        _colorLed.alpha = color.alpha;
      });
    }
  }

  _sendColor() {
    if (_characteristic != null) {
      _characteristic.write(utf8.encode(json.encode(_colorLed.toJson())),true);
    }
  }

}
