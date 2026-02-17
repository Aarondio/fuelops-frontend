import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<double?> extractMeterReading(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract all numbers from the recognized text
      final numbers = _extractNumbers(recognizedText.text);

      if (numbers.isEmpty) {
        return null;
      }

      // For meter readings, we typically want the largest number
      // as it represents the cumulative reading
      return numbers.reduce((a, b) => a > b ? a : b);
    } catch (e) {
      return null;
    }
  }

  List<double> _extractNumbers(String text) {
    final numbers = <double>[];

    // Pattern to match decimal numbers (with optional decimal point)
    // Handles formats like: 12345, 12345.6, 12,345.67, 12 345.6
    final regex = RegExp(r'[\d\s,]+\.?\d*');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final raw = match.group(0);
      if (raw == null || raw.trim().isEmpty) continue;

      // Clean up the number: remove spaces and commas
      final cleaned = raw.replaceAll(RegExp(r'[\s,]'), '');

      if (cleaned.isEmpty) continue;

      final number = double.tryParse(cleaned);
      if (number != null && number > 0) {
        numbers.add(number);
      }
    }

    return numbers;
  }

  Future<List<RecognizedNumber>> extractAllNumbers(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final numbers = <RecognizedNumber>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineNumbers = _extractNumbers(line.text);
          for (final number in lineNumbers) {
            numbers.add(RecognizedNumber(
              value: number,
              text: line.text,
              boundingBox: line.boundingBox,
            ));
          }
        }
      }

      // Sort by value descending (largest first)
      numbers.sort((a, b) => b.value.compareTo(a.value));

      return numbers;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class RecognizedNumber {
  final double value;
  final String text;
  final Rect? boundingBox;

  RecognizedNumber({
    required this.value,
    required this.text,
    this.boundingBox,
  });
}
