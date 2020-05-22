import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:led_strip/Bluetooth.dart';

void main() => runApp(MyApp());
//void main() => runApp(MyBluetooth());

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
  ColorLed({this.isOn,this.red,this.green,this.blue,this.alpha});
  factory ColorLed.fromJson(Map<String,dynamic> parsedJson) {
    return ColorLed(
      isOn: parsedJson["isOn"],
      red: parsedJson["red"],
      green: parsedJson["green"],
      blue: parsedJson["blue"],
      alpha: parsedJson["alpha"],
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

  final FlutterBlue flutterBlue = FlutterBlue.instance;
  Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {

  String BLE_NAME = "ESP32-led-strip-beb5483e";
  String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  String CHARACT_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  String CHARACT_UUID_TX = "beb5483e-36e1-4688-b7f5-c5c9c331914b";

  ColorLed _colorJson = new ColorLed(isOn: true, red: 0, green: 0, blue: 0, alpha: 0);
  Color _currentColor = Colors.blue;
  bool lightTheme = true;

  BluetoothDevice _connectedDevice;
  BluetoothCharacteristic _characteristic;
  BluetoothCharacteristic _characteristicTX;

  @override
  void initState() {
    super.initState();
      _connectToEsp();
  }

  _connectToEsp() {
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _setConnectedDevice(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _setConnectedDevice(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  _setConnectedDevice(BluetoothDevice device) {
    if (device.name == BLE_NAME) {
      device.connect().then((value) {
        widget.flutterBlue.stopScan();
        setState(() {
          _connectedDevice = device;
        });
        device.discoverServices().then((value) async {
          for (BluetoothService service in value) {
            if (service.uuid.toString() == SERVICE_UUID) {
              for (BluetoothCharacteristic characteristic in service.characteristics) {
                if (characteristic.uuid.toString() == CHARACT_UUID) {
                  characteristic.read().then((value) {

                    Map<String,dynamic> color = json.decode(utf8.decode(value));
                    setState(() {
                      this._colorJson = new ColorLed.fromJson(color);
                    });
                  });
                  setState(() {
                    _characteristic = characteristic;
                  });
                }
                if (characteristic.uuid.toString() == CHARACT_UUID_TX) {
                  setState(() {
                    _characteristicTX = characteristic;
                  });
                  _characteristicTX.value.listen((value) {
                    print("***** $value");
                  });
                  // TODO
                  //await _characteristicTX.setNotifyValue(true);
                }
              }
            }
          }
        });
      }).catchError((e) {
        if (e.code != 'already_connected') {
          throw e;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return (_connectedDevice == null) ? _bodyUnconnected() : _bodyConnected();
  }

  Widget _bodyUnconnected() {
    return Center(
      child: Column(
        children: <Widget>[
          Text('Connecting..'),
        ],
      ),
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
                  Column(
                    children: <Widget>[
                      Text('R : ${_colorJson.red}'), // int
                      Text('G : ${_colorJson.green}'),
                      Text('B : ${_colorJson.blue}'),
                      Text('A : ${_colorJson.alpha / 255 * 100} %'),
                    ],
                  ),
                  Switch(
                    value: _colorJson.isOn,
                    onChanged: (value) {
                      setState(() {
                        _colorJson.isOn = value;
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
                                pickerColor: _currentColor,
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
                    color: _currentColor,
                    textColor: useWhiteForeground(_currentColor)
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
    if (color != _currentColor) {
      setState(() {
        _currentColor = color;
        _colorJson.red = color.red;
        _colorJson.green = color.green;
        _colorJson.blue = color.blue;
        _colorJson.alpha = color.alpha;
      });
    }
  }

  _sendColor() {
    if (_characteristic != null) {
      _characteristic.write(utf8.encode(json.encode(_colorJson)));
    }
  }

}
