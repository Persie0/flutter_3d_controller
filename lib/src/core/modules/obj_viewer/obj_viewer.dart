import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_3d_controller/src/core/exception/flutter_3d_controller_exception.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math_64.dart';
import 'scene.dart';

typedef SceneCreatedCallback = void Function(
    Scene scene, String modelName, String? modelUrl,
    {bool isAsset});

class ObjViewer extends StatefulWidget {
  const ObjViewer({
    super.key,
    required this.src,
    this.interactive = true,
    this.onSceneCreated,
    this.onObjectCreated,
  });

  final bool interactive;
  final SceneCreatedCallback? onSceneCreated;
  final ObjectCreatedCallback? onObjectCreated;

  /// The URL or path to the 3D model. This parameter is required.
  /// Only .OBJ models are supported.
  final String src;

  @override
  State<ObjViewer> createState() => _ObjViewerState();
}

class _ObjViewerState extends State<ObjViewer> {
  late Scene scene;
  late Offset _lastFocalPoint;
  double? _lastZoom;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = null;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    scene.camera.trackBall(
        toVector2(_lastFocalPoint), toVector2(details.localFocalPoint), 1.25);
    _lastFocalPoint = details.localFocalPoint;
    if (_lastZoom == null) {
      _lastZoom = scene.camera.zoom;
    } else {
      scene.camera.zoom = _lastZoom! * details.scale;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    scene = Scene(
      onUpdate: () => setState(() {}),
      onObjectCreated: widget.onObjectCreated,
    );
    // prevent setState() or markNeedsBuild called during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modelSrcData = _parseModelSrc(widget.src);
      widget.onSceneCreated?.call(
          scene, modelSrcData.name ?? widget.src, modelSrcData.url,
          isAsset: modelSrcData.isAsset);
    });
  }

  @override
  void didUpdateWidget(covariant ObjViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      scene = Scene(
        onUpdate: () => setState(() {}),
        onObjectCreated: widget.onObjectCreated,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final modelSrcData = _parseModelSrc(widget.src);
        widget.onSceneCreated?.call(
            scene, modelSrcData.name ?? widget.src, modelSrcData.url,
            isAsset: modelSrcData.isAsset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      scene.camera.viewportWidth = constraints.maxWidth;
      scene.camera.viewportHeight = constraints.maxHeight;
      final customPaint = CustomPaint(
        painter: _ObjPainter(scene),
        size: Size(constraints.maxWidth, constraints.maxHeight),
      );
      return widget.interactive
          ? GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              child: customPaint,
            )
          : customPaint;
    });
  }
}

class _ObjPainter extends CustomPainter {
  final Scene _scene;
  const _ObjPainter(this._scene);

  @override
  void paint(Canvas canvas, Size size) {
    _scene.render(canvas, size);
  }

  // We should repaint whenever the board changes, such as board.selected.
  @override
  bool shouldRepaint(_ObjPainter oldDelegate) {
    return true;
  }
}

/// Convert Offset to Vector2
Vector2 toVector2(Offset value) {
  return Vector2(value.dx, value.dy);
}

({String? name, String? url, bool isAsset}) _parseModelSrc(String src) {
  if (!src.toLowerCase().endsWith('.obj')) {
    throw Flutter3dControllerFormatException();
  } else if (src.startsWith('http://') || src.startsWith('https://')) {
    //model is loading from url
    String modelName = src.substring(src.lastIndexOf('/') + 1);
    String modelPath = src.substring(0, src.lastIndexOf('/') + 1);
    return (name: modelName, url: modelPath, isAsset: false);
  } else if (src.startsWith('file://') || p.isAbsolute(src)) {
    //model is loading from local file
    return (name: src, url: null, isAsset: false);
  } else if (src.contains('assets')) {
    //model is loading from local asset
    return (name: src, url: null, isAsset: true);
  } else {
    throw Flutter3dControllerFormatException(
        message: 'Cannot Parse the model source.');
  }
}
