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

  List<String> _animations = ['STATIC', 'RAINBOW', 'WAVE', 'COP'];

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


                  Card(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(
                            Icons.brightness_7,
                            color: Colors.pink,
                          ),
                          trailing: Text(
                            _colorLed.type,
                            style: TextStyle(
                                color: Colors.grey
                            ),
                          ),
                          title: Text(
                            'Animations',
                            style: TextStyle(
                              color: (MediaQuery.of(context).platformBrightness == Brightness.dark) ? Colors.white : Colors.black,
                            ),
                          ),
                          onTap: () {
                            _settingsAnimation(context);
                          },
                        ),
                        ListTile(
                          title: ColorPicker(
                            pickerColor: _colorLed.color,
                            onColorChanged: changeColor,
                            colorPickerWidth: 300.0,
                            pickerAreaHeightPercent: 0.1,
                            enableAlpha: true,
                            displayThumbColor: true,
                            showLabel: false,
                            paletteType: PaletteType.rgb,
                            pickerAreaBorderRadius: const BorderRadius.only(
                              topLeft: const Radius.circular(2.0),
                              topRight: const Radius.circular(2.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RaisedButton(
                        onPressed: () {
                          _characteristic.read().then((value) {
                            Map<String,dynamic> response = json.decode(utf8.decode(value));
                            setState(() {
                              _colorLed = new ColorLed.fromJson(response);
                            });
                          }).catchError((e) {
                            print('*** Error read characteristic $CHARACT_UUID');
                            print(e);
                          });
                        },
                        child: Text('Reset'),
                      ),
                      RaisedButton(
                        onPressed: () => _sendColor(),
                        child: Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            )
        )
    );
  }

  _settingsAnimation(context) {
    List<Widget> listTiles = [];
    _animations.forEach((animation) {
      listTiles.add(ListTile(
        leading: (_colorLed.type == animation) ? Icon(Icons.check) : Text(''),
        title: Text(animation),
        onTap: () {
          setState(() {
            _colorLed.type = animation;
          });
          //_sendColor();
          Navigator.pop(context);
        },
      ));
    });

    showModalBottomSheet(
        backgroundColor: (MediaQuery.of(context).platformBrightness == Brightness.dark) ? Colors.grey : Colors.white,
        context: context,
        builder: (BuildContext builder) {
          return Container(
            child: Wrap(
              children: listTiles,
            ),
          );
        }
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
