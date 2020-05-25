import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'classes/ColorLed.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP led',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
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
  Characteristic _characteristic;

  @override
  void initState() {
    super.initState();
    _bleManager.createClient().then((value) => _connectToEsp());
  }
  
  _connectToEsp() {
    _bleManager.startPeripheralScan().listen((ScanResult scanResult) {
      print('*** START SCAN');
      print(scanResult.peripheral.name);
      if (scanResult.peripheral.name == BLE_NAME) {
        scanResult.peripheral.connect().then((value) {
          print("esp connected..");
          _bleManager.stopPeripheralScan();
          setState(() {
            _esp = scanResult.peripheral;
          });
          _esp.discoverAllServicesAndCharacteristics().then((value) {
            _esp.requestMtu(512).then((value) {
              _esp.characteristics(SERVICE_UUID).then((characteristics) {
                for (Characteristic characteristic in characteristics) {
                  // Char read/write
                  if (characteristic.uuid == CHARACT_UUID) {
                    setState(() {
                      _characteristic = characteristic;
                    });
                    _characteristic.read().then((value) {
                      Map<String,dynamic> response = json.decode(utf8.decode(value));
                      setState(() {
                        _colorLed = new ColorLed.fromJson(response);
                      });
                    }).catchError((e) {
                      print('*** Error read characteristic $CHARACT_UUID');
                      print(e);
                    });
                  }
                  // Char notification
                  if (characteristic.uuid == CHARACT_UUID_TX) {
                    characteristic.monitor().listen((value) {
                      print(value);
                      Map<String,dynamic> response = json.decode(utf8.decode(value));
                      setState(() {
                        _colorLed = new ColorLed.fromJson(response);
                      });
                    });
                  }
                }
              }).catchError((e) {
                print('*** Error get characteristics of service $SERVICE_UUID');
                print(e);
              });
            }).catchError((e) {
              print('*** Error set MTU');
              print(e);
            });
          }).catchError((e) {
            print('*** Error discover services and characteristics');
          print(e);
          });
        }).catchError((e) {
          print('*** Error connect');
          print(e);
        });
      }
    });
  }

  @override
  void dispose() {
    _esp.disconnectOrCancelConnection();
    _bleManager.destroyClient();
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
                  Text('Connected to ${_esp.name}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        onPressed: () {
                          setState(() {
                            _colorLed.isOn = true;
                          });
                          _sendColor();
                        },
                        child: Text('ON'),
                        color: (_colorLed.isOn) ? Colors.blue : Colors.white,
                      ),
                      FlatButton(
                        onPressed: () {
                          setState(() {
                            _colorLed.isOn = false;
                          });
                          _sendColor();
                        },
                        child: Text('OFF'),
                        color: (_colorLed.isOn) ? Colors.white : Colors.blue,
                      ),
                    ],
                  ),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        onPressed: () {
                          setState(() {
                            _colorLed.type = 'STATIC';
                          });
                          _sendColor();
                        },
                        child: Text('STATIC'),
                        color: (_colorLed.type == 'STATIC') ? Colors.blue : Colors.white,
                      ),
                      FlatButton(
                        onPressed: () {
                          setState(() {
                            _colorLed.type = 'RAINBOW';
                          });
                          _sendColor();
                        },
                        child: Text('RAINBOW'),
                        color: (_colorLed.type == 'RAINBOW') ? Colors.blue : Colors.white,
                      ),
                      FlatButton(
                        onPressed: () {
                          setState(() {
                            _colorLed.type = 'WAVE';
                          });
                          _sendColor();
                        },
                        child: Text('WAVE'),
                        color: (_colorLed.type == 'WAVE') ? Colors.blue : Colors.white,
                      ),
                    ],
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
