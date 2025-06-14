import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceLiveScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Future<void> Function(File file) onFaceCaptured;

  const FaceLiveScanScreen({
    Key? key,
    required this.cameras,
    required this.onFaceCaptured,
  }) : super(key: key);

  @override
  State<FaceLiveScanScreen> createState() => _FaceLiveScanScreenState();
}

class _FaceLiveScanScreenState extends State<FaceLiveScanScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  bool _isDetecting = false;
  String? _capturedImagePath;
  bool _isCameraInitialized = false;
  List<Face> _faces = [];
  int _selectedCameraIndex = 0;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _controller = CameraController(
      widget.cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _capturedImagePath = null;
        _isProcessingImage = false;
      });
      _startImageStream();
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    });

    await _controller?.dispose();
    await _initializeCamera();
  }

  void _startImageStream() {
    _controller!.startImageStream((CameraImage image) async {
      if (_isDetecting || _isProcessingImage || _capturedImagePath != null) return;

      _isDetecting = true;

      try {
        final XFile imageFile = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(imageFile.path);

        final faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
          });
          if (faces.isNotEmpty && !_isProcessingImage && _capturedImagePath == null) {
            _isProcessingImage = true;
            await _controller!.stopImageStream();
            File fixedFile = await _fixImageOrientation(File(imageFile.path));
            setState(() {
              _capturedImagePath = fixedFile.path;
            });
          }
        }
      } catch (e) {
        print('Error detecting faces: $e');
      }

      _isDetecting = false;
    });
  }

  Future<void> _onSend() async {
    if (_capturedImagePath != null) {
      await widget.onFaceCaptured(File(_capturedImagePath!));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _onRetake() async {
    setState(() {
      _capturedImagePath = null;
      _isProcessingImage = false;
      _faces = [];
    });
    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<File> _fixImageOrientation(File file) async {
    final bytes = await file.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return file;

    final fixedImage = img.bakeOrientation(originalImage);
    final fixedFile = await file.writeAsBytes(img.encodeJpg(fixedImage));
    return fixedFile;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Face Scan'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.cameras.length > 1 && _capturedImagePath == null)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                if (_capturedImagePath == null)
                  CameraPreview(_controller!)
                else
                  Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Image.file(
                      File(_capturedImagePath!),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                if (_capturedImagePath == null)
                  CustomPaint(
                    painter: FaceDetectorPainter(
                      faces: _faces,
                      imageSize: Size(
                        _controller!.value.previewSize!.height,
                        _controller!.value.previewSize!.width,
                      ),
                    ),
                  ),
                if (_capturedImagePath != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _onRetake,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _onSend,
                            icon: const Icon(Icons.send),
                            label: const Text('Send'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FaceDetectorPainter({
    required this.faces,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final Face face in faces) {
      canvas.drawRect(
        _scaleRect(
          rect: face.boundingBox,
          imageSize: imageSize,
          widgetSize: size,
        ),
        paint,
      );
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}