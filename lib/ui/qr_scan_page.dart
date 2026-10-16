import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'theme.dart';
import 'widgets.dart';

/// Camera QR scanner (with gallery import). Pops with the decoded text.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  void _finish(String? v) {
    if (_done || v == null || v.isEmpty) return;
    _done = true;
    Navigator.pop(context, v);
  }

  Future<void> _gallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final res = await _ctrl.analyzeImage(x.path);
    final codes = res?.barcodes ?? const <Barcode>[];
    if (codes.isEmpty || codes.first.rawValue == null) {
      if (mounted) toast(context, 'QR در تصویر پیدا نشد', error: true);
      return;
    }
    _finish(codes.first.rawValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('اسکن QR', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () => _ctrl.toggleTorch(), icon: const Icon(Icons.flash_on_rounded)),
          IconButton(onPressed: () => _ctrl.switchCamera(), icon: const Icon(Icons.cameraswitch_rounded)),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (capture) {
            final codes = capture.barcodes;
            if (codes.isEmpty) return;
            _finish(codes.first.rawValue);
          },
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: p.primary, width: 3),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: LuxButton(label: 'انتخاب QR از گالری', icon: Icons.photo_library_rounded, onTap: _gallery),
        ),
      ]),
    );
  }
}
