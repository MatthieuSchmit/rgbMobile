/*
 * led_strip - /Bluetooth
 *
 * by Matthieu S. at 18-05-20 17:14
 *
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class MyBluetooth extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter BLE Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {

  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services = [];
  final _writeController = TextEditingController();

  _addDeviceToList(BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  _startScan() {
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceToList(device);
      }
    });

    widget.flutterBlue.scanResults
        .listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceToList(result.device);
      }
    });

    widget.flutterBlue.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildView(),
    );
  }

  ListView _buildView() {
    if (_connectedDevice != null) {
      return _connectedDeviceView();
    } else {
      return _devicesListView();
    }
  }

  ListView _devicesListView() {
    List<Container> containers = [];
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(Container(
        height: 50,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(device.name ?? "unknown device"),
                  Text(device.id.toString()),
                ],
              ),
            ),
            FlatButton(
              child: Text('Connect'),
              onPressed: () {
                widget.flutterBlue.stopScan();
                device.connect().then((value) {
                  device.discoverServices().then((value) {
                    setState(() {
                      _services = value;
                      _connectedDevice = device;
                    });
                  });
                }).catchError((e) {
                  if (e.code != 'already_connected') {
                    throw e;
                  }
                }).whenComplete(() {

                });

              },
            )
          ],
        ),
      ));
    }
    return ListView(children: containers,);
  }

  ListView _connectedDeviceView() {
    List<Container> containers = [];

    containers.add(Container(
      height: 50,
      child: RaisedButton(
        onPressed: () {
          _connectedDevice.disconnect().then((value) {
            setState(() {
              _services = [];
              _connectedDevice = null;
            });
            _startScan();
          }).catchError((e) {
            throw e;
          });
        },
        child: Text('Disconnect'),
      ),
    ));

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = new List<Widget>();
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristic.value.listen((value) {
          print(value);
        });
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: _buildReadWriteNotifyButton(characteristic),
                ),
                Row(
                  children: <Widget>[
                    Text('values : ' + widget.readValues[characteristic.uuid].toString())
                  ],
                ),
                Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        Container(
          child: ExpansionTile(
              title: Text(service.uuid.toString()),
              children: characteristicsWidget),
        ),
      );
    }

    return ListView(
      children: containers,
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = new List<ButtonTheme>();

    if (characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              color: Colors.blue,
              child: Text('READ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                var sub = characteristic.value.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('WRITE', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Write"),
                        content: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _writeController,
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: Text("Send"),
                            onPressed: () {
                              characteristic.write(utf8
                                  .encode(_writeController.value.text));
                              Navigator.pop(context);
                            },
                          ),
                          FlatButton(
                            child: Text("Cancel"),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('NOTIFY', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                characteristic.value.listen((value) {
                  widget.readValues[characteristic.uuid] = value;
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }

    return buttons;
  }

}