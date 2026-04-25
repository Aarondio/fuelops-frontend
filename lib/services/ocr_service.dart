import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrScanResult {
  final List<RecognizedNumber> numbers;
  final double? confidence;

  const OcrScanResult({required this.numbers, this.confidence});
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<double?> extractMeterReading(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final numbers = _extractNumbers(recognizedText.text);
      if (numbers.isEmpty) return null;
      return numbers.reduce((a, b) => a > b ? a : b);
    } catch (e) {
      return null;
    }
  }

  List<double> _extractNumbers(String text) {
    final numbers = <double>[];
    final regex = RegExp(r'[\d\s,]+\.?\d*');
    final matches = regex.allMatches(text);
    for (final match in matches) {
      final raw = match.group(0);
      if (raw == null || raw.trim().isEmpty) continue;
      final cleaned = raw.replaceAll(RegExp(r'[\s,]'), '');
      if (cleaned.isEmpty) continue;
      final number = double.tryParse(cleaned);
      if (number != null && number > 0) numbers.add(number);
    }
    return numbers;
  }

  Future<List<RecognizedNumber>> extractAllNumbers(File imageFile) async {
    final result = await scan(imageFile);
    return result.numbers;
  }

  Future<OcrScanResult> scan(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final numbers = <RecognizedNumber>[];
      double confidenceSum = 0;
      int confidenceCount = 0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            final conf = element.confidence;
            if (conf != null && conf > 0) {
              confidenceSum += conf;
              confidenceCount++;
            }
          }
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

      numbers.sort((a, b) => b.value.compareTo(a.value));

      final confidence = confidenceCount > 0
          ? (confidenceSum / confidenceCount) * 100
          : null;

      return OcrScanResult(numbers: numbers, confidence: confidence);
    } catch (e) {
      return const OcrScanResult(numbers: [], confidence: null);
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
