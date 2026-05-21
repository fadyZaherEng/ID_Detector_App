import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

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
      'gemini-3.1-flash-lite',
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

        final cleanedResponse = responseText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

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

    if (lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg')) {
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
}