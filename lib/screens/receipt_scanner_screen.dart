import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ReceiptScannerScreenState createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  // ignore: deprecated_member_use
  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();
  
  String? _scannedText;
  bool _isScanning = false;
  String? _errorMessage;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isScanning = true;
        _scannedText = null; // Reset scanned text when a new image is picked
        _errorMessage = null; // Clear any previous error messages
      });
      _scanText(_image!);
    }
  }

  Future<void> _scanText(File image) async {
    final inputImage = InputImage.fromFile(image);

    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      setState(() {
        _scannedText = recognizedText.text;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error scanning receipt: $e';
      });
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void _addExpenseFromReceipt() {
    if (_scannedText != null) {
      // Example: Parse title and amount from the scanned text
      String title = "Unknown Item";
      double amount = 0.0;

      final lines = _scannedText!.split('\n');
      for (var line in lines) {
        final amountMatch = RegExp(r'(\d+.\d{2})').firstMatch(line);
        if (amountMatch != null) {
          title = line.split(' ').first; // Extract title
          amount = double.parse(amountMatch.group(0)!); // Extract amount
          break;
        }
      }

      Navigator.pop(context, {
        'title': title,
        'amount': amount,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: Column(
        children: [
          if (_image != null)
            Image.file(
              _image!,
              height: 200,
              fit: BoxFit.cover,
            ),
          const SizedBox(height: 20),
          if (_isScanning)
            const CircularProgressIndicator()
          else if (_scannedText != null)
            Expanded(
              child: SingleChildScrollView(
                child: Text(_scannedText!),
              ),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            )
          else
            const Text('No text recognized yet.'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.image),
      ),
      bottomNavigationBar: _scannedText != null
          ? ElevatedButton(
              onPressed: _addExpenseFromReceipt,
              child: const Text('Add Expense'),
            )
          : null,
    );
  }
}
