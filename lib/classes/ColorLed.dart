/*
 * led_strip - classes/ColorLed
 *
 * by Matthieu S. at 25-05-20 12:22
 *
 */

import 'package:flutter/material.dart';

class ColorLed {
  bool isOn;
  int red;
  int green;
  int blue;
  int alpha;
  Color color;
  String type; // STATIC, RAINBOW, WAVE, COP

  ColorLed({this.isOn,this.red,this.green,this.blue,this.alpha,this.color,this.type});

  factory ColorLed.fromJson(Map<String,dynamic> parsedJson) {
    return ColorLed(
        isOn: parsedJson["isOn"],
        red: parsedJson["red"],
        green: parsedJson["green"],
        blue: parsedJson["blue"],
        alpha: parsedJson["alpha"],
        color: new Color.fromARGB(parsedJson["alpha"], parsedJson["red"], parsedJson["green"], parsedJson["blue"]),
        type: parsedJson['type']
    );
  }

  Map<String,dynamic> toJson() {
    return {
      "isOn": this.isOn,
      "red" : this.red,
      "green" : this.green,
      "blue" : this.blue,
      "alpha" : this.alpha,
      "type" : this.type,
    };
  }
}
