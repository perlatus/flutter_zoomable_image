import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zoomable_image/zoomable_image.dart';

void main() {
  runApp(new ZoomableImage(new AssetImage('images/square.png'), scale: 16.0));
}
