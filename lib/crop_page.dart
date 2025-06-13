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
  // Create a CropController with desired settings.
  final CropController _controller = CropController(
    aspectRatio: 1,
    defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
  );

  @override
  Widget build(BuildContext context) {
    // Determine the image source.
    Image imageWidget;
    if (widget.imageFile != null) {
      imageWidget = Image.file(widget.imageFile!);
    } else if (widget.imagePath != null) {
      imageWidget = Image.file(File(widget.imagePath!));
    } else if (widget.imageBytes != null) {
      imageWidget = Image.memory(widget.imageBytes!);
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text("Crop Image")),
        body: const Center(child: Text("No image found to crop.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Image"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Capture Navigator and ScaffoldMessenger early.
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                // Perform cropping.
                final ui.Image croppedBitmap =
                    await _controller.croppedBitmap();
                final byteData = await croppedBitmap.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                if (!mounted) return;
                final Uint8List croppedBytes = byteData!.buffer.asUint8List();
                navigator.pop(croppedBytes);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text("Cropping failed: $e")),
                );
              }
            },
          )
        ],
      ),
      body: CropImage(
        controller: _controller,
        image: imageWidget,
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
    );
  }
}
