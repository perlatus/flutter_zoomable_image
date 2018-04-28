import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ZoomableImage extends StatefulWidget {
  ZoomableImage(this.image, {
    Key key,
    this.scale = 2.0,
    this.onTap,
    this.backgroundColor = Colors.black,
  })
      : super(key: key);

  final ImageProvider image;
  final double scale;
  final Color backgroundColor;

  final GestureTapCallback onTap;

  @override
  _ZoomableImageState createState() => new _ZoomableImageState(scale);
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> {
  final double _maxScale;
  _ZoomableImageState(this._maxScale);

  ImageStream _imageStream;
  ui.Image _image;
  Size _imageSize;

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset; // where the top left corner of the image is drawn

  double _previousZoom;
  double _zoom; // multiplier applied to scale the full image

  @override
  Widget build(BuildContext ctx) => _image == null
      ? new Container()
      : new LayoutBuilder(builder: _buildLayout);

  Widget _buildLayout(BuildContext ctx, BoxConstraints constraints) {
    if (_offset == null || _zoom == null) {
      _imageSize = new Size(
        _image.width.toDouble(),
        _image.height.toDouble(),
      );

      Size canvas = constraints.biggest;
      Size fitted = _containmentSize(canvas, _imageSize);

      Offset delta = canvas - fitted;
      _offset = delta / 2.0; // Centers the image

      _zoom = canvas.width / _imageSize.width;
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
      child: new Container(color: widget.backgroundColor),
      foregroundPainter: new _ZoomableImagePainter(
        image: _image,
        offset: _offset,
        zoom: _zoom,
      ),
    );
  }

  void _handleDoubleTap(BuildContext ctx) {
    double newZoom = _zoom * 2;
    if (newZoom > _maxScale) {
      return;
    }

    // We want to zoom in on the center of the screen.
    // Since we're zooming by a factor of 2, we want the new offset to be twice
    // as far from the center in both width and height than it is now.
    Offset center = ctx.size.center(Offset.zero);
    Offset newOffset = _offset - (center - _offset);

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
    if (newZoom > _maxScale) {
      return;
    }

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousZoom;
    final Offset newOffset = d.focalPoint - normalizedOffset * newZoom;

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
    Size targetSize = imageSize * zoom;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.zoom != zoom;
  }
}
