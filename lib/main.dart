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

  bool lightTheme = true;
  Color currentColor = Colors.limeAccent;

  BluetoothDevice _connectedDevice;
  BluetoothCharacteristic _characteristic;
  BluetoothCharacteristic _characteristicTX;

  @override
  void initState() {
    super.initState();
   // if (_connectedDevice == null)
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
        device.discoverServices().then((value) {
          for (BluetoothService service in value) {
            if (service.uuid.toString() == SERVICE_UUID) {
              for (BluetoothCharacteristic characteristic in service.characteristics) {
                if (characteristic.uuid.toString() == CHARACT_UUID) {
                  setState(() {

                    _characteristic = characteristic;
                  });
                }
                if (characteristic.uuid.toString() == CHARACT_UUID_TX) {
                  setState(() {
                    _characteristicTX = characteristic;
                  });
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
                      Text('R : ${currentColor.red}'), // int
                      Text('G : ${currentColor.green}'),
                      Text('B : ${currentColor.blue}'),
                      Text('A : ${currentColor.alpha / 255 * 100} %'),
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
                                pickerColor: currentColor,
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
                    color: currentColor,
                    textColor: useWhiteForeground(currentColor)
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
    if (color != currentColor) {
      setState(() {
        currentColor = color;
      });
    }
  }

  _sendColor() {
    if (_characteristic != null) {
      int red = currentColor.red;
      int green = currentColor.green;
      int blue = currentColor.blue;
      double alpha = currentColor.alpha / 255 * 100;

      if (red != 0) {
        red = (red * alpha / 100).toInt();
      }
      if (green != 0) {
        green = (green * alpha / 100).toInt();
      }
      if (blue != 0) {
        blue = (blue * alpha / 100).toInt();
      }


      String rrr = (red < 10) ? '00$red' : (red < 100) ? '0$red' : '$red';
      String ggg = (green < 10) ? '00$green' : (green < 100) ? '0$green' : '$green';
      String bbb = (blue < 10) ? '00$blue' : (blue < 100) ? '0$blue' : '$blue';

      print("$rrr,$ggg,$bbb");

      _characteristic.write(utf8.encode("$rrr,$ggg,$bbb"));
    }
  }

}
