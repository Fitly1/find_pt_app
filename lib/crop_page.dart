// lib/crop_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';

class CropPage extends StatefulWidget {
  final String? imagePath;
  final File? imageFile;
  final Uint8List? imageBytes;

  const CropPage({
    super.key,
    this.imagePath,
    this.imageFile,
    this.imageBytes,
  });

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  // 1 : 1 aspect ratio by default
  final CropController _controller = CropController(
    aspectRatio: 1,
    defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
  );

  bool _isCropping = false; // to show the overlay & block double-tap

  Future<void> _onCropPressed() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);

    try {
      // 1️⃣  Produce the cropped bitmap (heavy native work, already async)
      final ui.Image img = await _controller.croppedBitmap();

      // 2️⃣  Convert to PNG bytes (runs on the UI isolate, but fast enough)
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();

      if (!mounted) return;
      Navigator.of(context).pop(bytes); // send cropped image back
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cropping failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Select the image source.
    Image? img;
    if (widget.imageFile != null) {
      img = Image.file(widget.imageFile!);
    } else if (widget.imagePath != null) {
      img = Image.file(File(widget.imagePath!));
    } else if (widget.imageBytes != null) {
      img = Image.memory(widget.imageBytes!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onCropPressed,
          ),
        ],
      ),
      body: img == null
          ? const Center(child: Text('No image found to crop.'))
          : Stack(
              children: [
                CropImage(
                  controller: _controller,
                  image: img,
                  gridColor: Colors.white.withAlpha((255 * 0.7).round()),
                  gridInnerColor: Colors.white,
                  gridCornerColor: Colors.white,
                  gridCornerSize: 50,
                  showCorners: true,
                  gridThinWidth: 3,
                  gridThickWidth: 6,
                  scrimColor: Colors.grey.withAlpha((255 * 0.5).round()),
                  alwaysShowThirdLines: true,
                  minimumImageSize: 50,
                  maximumImageSize: 2000,
                ),
                if (_isCropping)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
    );
  }
}
