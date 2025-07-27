//import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 2000,
    returnImage: true,
  );
  bool _scanned = false;
  bool _processingImage = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (_scanned || _processingImage) return;
              _processingImage = true;

              try {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No valid QR code detected.')),
                  );
                  setState(() {
                    _processingImage = false;
                  });
                  return;
                }

                final Barcode barcode = barcodes.first;
                final String? rawValue = barcode.rawValue;
                print("Scanned QR Value: $rawValue");

                Uint8List? imageBytes = capture.image;

                if (rawValue != null) {
                  _scanned = true;
                  Navigator.pop(context, {
                    'image': imageBytes,
                    'result': rawValue,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid QR code detected.')),
                  );
                  setState(() {
                    _processingImage = false;
                  });
                }
              } catch (e) {
                print("Error in QR scanner: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
                setState(() {
                  _processingImage = false;
                });
              }
            },
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Align QR code within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}