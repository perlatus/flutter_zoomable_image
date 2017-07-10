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
  Size _imageSize;

  // These values are treated as if unscaled.

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset;

  double _previousZoom;
  double _zoom = 1.0;

  @override
  Widget build(BuildContext ctx) => _image == null
      ? new Container()
      : new LayoutBuilder(builder: _buildLayout);

  Widget _buildLayout(BuildContext ctx, BoxConstraints constraints) {
    if (_offset == null) {
      _imageSize = new Size(
        _image.width.toDouble(),
        _image.height.toDouble(),
      );

      Size canvas = constraints.biggest;
      Size fitted = _containmentSize(canvas, _imageSize);

      Offset delta = canvas - fitted;
      _offset = delta / 2.0; // Centers the image
    }

    return new GestureDetector(
      child: _child(),
      onTap: widget.onTap,
      onDoubleTap: () => _handleDoubleTap(ctx),
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
    );
  }

  Widget _child() {
    return new CustomPaint(
      painter: new _ZoomableImagePainter(
        image: _image,
        offset: _offset,
        zoom: _zoom,
      ),
    );
  }

  void _handleDoubleTap(BuildContext ctx) {
    // double zoom => center to left corner distance doubles
    // offset = offset - size / 2

    Size fitted = _containmentSize(ctx.size, _imageSize);
    double newZoom = _zoom * 2;
    Offset newOffset = _offset - new Offset(fitted.width, fitted.height) / 2.0;

    if (newZoom > _scale) {
      return;
    }
    setState(() {
      _zoom = newZoom;
      _offset = newOffset;
    });
  }

  void _handleScaleStart(ScaleStartDetails d) {
    print("starting scale at ${d.focalPoint} from $_offset $_zoom");
    _startingFocalPoint = d.focalPoint;
    _previousOffset = _offset;
    _previousZoom = _zoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    double newZoom = _previousZoom * d.scale;
    if (newZoom > _scale) {
      return;
    }

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousZoom;
    final Offset newOffset = d.focalPoint - normalizedOffset * _zoom;

    print("offset: $newOffset; zoom: $newZoom");

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
    print("image loaded: $info");
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

// Given a canvas and an image, determine what size the image should be to be contained in but not
// exceed the canvas while preserving its aspect ratio.
Size _containmentSize(Size canvas, Size image) {
  double canvasRatio = canvas.width / canvas.height;
  double imageRatio = image.width / image.height;

  if (canvasRatio < imageRatio) {
    // fat
    return new Size(canvas.width, canvas.width / imageRatio);
  } else if (canvasRatio > imageRatio) {
    // skinny
    return new Size(canvas.height * imageRatio, canvas.height);
  } else {
    return canvas;
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.zoom});

  final ui.Image image;
  final Offset offset;
  final double zoom;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = new Size(image.width.toDouble(), image.height.toDouble());
    Size targetSize = _containmentSize(canvasSize, imageSize) * zoom;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
    );
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.zoom != zoom;
  }
}
