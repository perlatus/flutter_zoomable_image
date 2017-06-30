import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class ZoomableImage extends StatefulWidget {
  ZoomableImage(this.image, {Key key, this.scale = 2.0, this.onTap})
      : super(key: key);

  final ImageProvider image;
  final double scale;

  final GestureTapCallback onTap;

  @override
  _ZoomableImageState createState() => new _ZoomableImageState(scale);
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> {
  final double _scale;
  _ZoomableImageState(this._scale);

  ImageStream _imageStream;
  ui.Image _image;

  // These values are treated as if unscaled.

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset = Offset.zero;

  double _previousZoom;
  double _zoom = 1.0;

  @override
  Widget build(BuildContext ctx) {
    if (_image == null) {
      return new Container();
    }

    return new GestureDetector(
      child: _child(),
      onTap: widget.onTap,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: (d) => _handleScaleUpdate(ctx.size, d),
    );
  }

  Widget _child() {
    // Painting in a small box and blowing it up works, whereas painting in a large box and
    // shrinking it down doesn't because the gesture area becomes smaller than the screen.
    //
    // This is bit counterintuitive because it's backwards, but it works.

    Widget bloated = new CustomPaint(
      painter: new _ZoomableImagePainter(
        image: _image,
        offset: _offset,
        zoom: _zoom / _scale,
      ),
    );

    return new Transform(
      transform: new Matrix4.diagonal3Values(_scale, _scale, _scale),
      child: bloated,
    );
  }

  void _handleScaleStart(ScaleStartDetails d) {
    _startingFocalPoint = d.focalPoint / _scale;
    _previousOffset = _offset;
    _previousZoom = _zoom;
  }

  void _handleScaleUpdate(Size size, ScaleUpdateDetails d) {
    double newZoom = _previousZoom * d.scale;
    bool tooZoomedIn = _image.width * _scale / newZoom <= size.width ||
        _image.height * _scale / newZoom <= size.height;
    if (tooZoomedIn) {
      return;
    }

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousZoom;
    final Offset newOffset = d.focalPoint / _scale - normalizedOffset * _zoom;

    setState(() {
      _zoom = newZoom;
      _offset = newOffset;
    });
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    print("image loaded: $info $synchronousCall");
    setState(() {
      _image = info.image;
    });
  }

  @override
  void dispose() {
    _imageStream.removeListener(_handleImageLoaded);
    super.dispose();
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.zoom});

  final ui.Image image;
  final Offset offset;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(canvas: canvas, rect: offset & (size * zoom), image: image);
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.zoom != zoom;
  }
}
