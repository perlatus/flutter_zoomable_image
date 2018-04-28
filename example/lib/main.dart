import 'package:flutter/material.dart';
import 'package:zoomable_image/zoomable_image.dart';

void main() {
  runApp(
    new MaterialApp(
      home: new Scaffold(
        body: new ZoomableImage(
            new AssetImage('images/squirrel.jpg'),
            backgroundColor: Colors.red),
      ),
    ),
  );
}
