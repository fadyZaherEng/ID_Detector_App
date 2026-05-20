import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/detection_result.dart';

class AiDetectorService {
  static Future<DetectionResult> detectIdCard({
    required File imageFile,
    required String apiKey,
  }) async {
    final modelsToTry = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ];

    Object? lastError;

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    const prompt = '''
Analyze the provided image and determine if it is an official identification document.

Official identification documents include:
- National ID Cards
- Passports
- Driver's Licenses
- State IDs
- Resident Cards
- Similar government-issued photo identification

Return ONLY valid JSON with this structure:

{
  "is_id_card": true,
  "confidence": 0.98,
  "document_type": "National ID",
  "extracted_details": {
    "full_name": "",
    "id_number": "",
    "expiry_date": "",
    "issuing_country": "",
    "date_of_birth": ""
  },
  "reasoning": ""
}

Rules:
- Do not use markdown
- Do not wrap JSON in ``` blocks
- Return raw JSON only
- If no ID is detected:
  - set is_id_card to false
  - document_type to "Not an ID Card"
  - extracted_details to {}
''';

    for (final modelName in modelsToTry) {
      try {
        print('Trying model: $modelName');

        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey.trim(),
          generationConfig: GenerationConfig(
            temperature: 0,
            responseMimeType: 'application/json',
          ),
        );

        final response = await model.generateContent([
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ]),
        ]);

        final responseText = response.text;

        print('Response from $modelName: $responseText');

        if (responseText == null || responseText.trim().isEmpty) {
          throw Exception('Empty response from Gemini.');
        }

        final cleanedResponse =
            responseText.replaceAll('```json', '').replaceAll('```', '').trim();

        final decoded = jsonDecode(cleanedResponse);

        return DetectionResult.fromJson(decoded);
      } catch (e) {
        lastError = e;

        print(
          'Model $modelName failed with error: $e',
        );
        // If the error is likely temporary (e.g., server overloaded or quota limit), wait a moment before trying the next model.
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('unavailable') ||
            errorMsg.contains('quota') ||
            errorMsg.contains('rate limit')) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    throw Exception(
      'All Gemini models failed. Last error: $lastError',
    );
  }

  static String _getMimeType(String filePath) {
    final lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }

  static String _convertArabicDigitsToEnglish(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String output = input;
    for (int i = 0; i < 10; i++) {
      output = output.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return output;
  }

  static Future<DetectionResult> detectIdCardLocally(
      {required File imageFile}) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Normalize Arabic numerals to standard English digits
      final text = _convertArabicDigitsToEnglish(recognizedText.text);
      final lowerText = text.toLowerCase();

      bool isId = false;
      String docType = 'Not an ID Card';
      double confidence = 0.0;
      final Map<String, String> details = {};
      String reasoning = '';

      // Detection indicators
      final hasIdKeyword = lowerText.contains('national') ||
          lowerText.contains('identity') ||
          lowerText.contains('card') ||
          lowerText.contains('government') ||
          lowerText.contains('republic') ||
          lowerText.contains('egypt') ||
          lowerText.contains('مصر') ||
          lowerText.contains('القومي') ||
          lowerText.contains('بطاقة') ||
          lowerText.contains('شخصية');

      final hasPassportKeyword = lowerText.contains('passport') ||
          lowerText.contains('جواز') ||
          lowerText.contains('سفر');

      final hasLicenseKeyword = lowerText.contains('license') ||
          lowerText.contains('driving') ||
          lowerText.contains('driver') ||
          lowerText.contains('رخصة') ||
          lowerText.contains('قيادة');

      if (hasPassportKeyword) {
        isId = true;
        docType = 'Passport';
        confidence = 0.90;
      } else if (hasLicenseKeyword) {
        isId = true;
        docType = "Driver's License";
        confidence = 0.92;
      } else if (hasIdKeyword) {
        isId = true;
        docType = 'National ID Card';
        confidence = 0.88;
      }

      if (isId) {
        reasoning =
            'Local ML Kit OCR scanned the image and successfully identified key text structures indicating a $docType. This verification was processed 100% locally on the device.';

        // Extract 14-digit Egyptian ID if exists (could have spaces between digits)
        final egyptIdRegex = RegExp(r'\d(?:\s*\d){13}');
        final matchId = egyptIdRegex.firstMatch(text);
        if (matchId != null) {
          final matchedStr = matchId.group(0)!;
          // Remove spaces to get clean 14 digits
          details['id_number'] = matchedStr.replaceAll(RegExp(r'\s+'), '');
        }

        // Extract potential date values (YYYY-MM-DD or DD/MM/YYYY)
        final dateRegex = RegExp(
            r'\b\d{2}[-/.]\d{2}[-/.]\d{4}\b|\b\d{4}[-/.]\d{2}[-/.]\d{2}\b');
        final dates =
            dateRegex.allMatches(text).map((m) => m.group(0)!).toList();
        if (dates.isNotEmpty) {
          details['dates_found'] = dates.join(', ');
        }

        // Include first 100 characters of scanned text
        final snippet = text.replaceAll('\n', ' ').trim();
        details['scanned_text'] =
            snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet;
      } else {
        reasoning =
            'Local ML Kit OCR scanned the image but could not find any typical text indicators matching a National ID, Passport, or Driver\'s License. No government headers or standard ID patterns were detected. Note: Local OCR only supports English/Latin-based text; for Arabic IDs, please use Gemini AI.';
      }

      return DetectionResult(
        isIdCard: isId,
        confidence: confidence,
        documentType: docType,
        extractedDetails: details,
        reasoning: reasoning,
      );
    } catch (e) {
      throw Exception('Local OCR scanning failed: $e');
    } finally {
      textRecognizer.close();
    }
  }
}
