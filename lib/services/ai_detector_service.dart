import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/detection_result.dart';

class AiDetectorService {
  /// Detects whether an image contains an ID‑card‑type document.
  static Future<DetectionResult> detectIdCard({
    required File imageFile,
    required String apiKey,
  }) async {
    // **Use a supported Gemini model ID** – adjust as needed.
    const modelName = 'gemini-3.1-flash-lite';

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
- Similar government‑issued photo IDs

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
If no ID is detected, set `is_id_card` to false and `extracted_details` to {}.
''';

    const maxAttempts = 4;
    var attempt = 0;
    var backoff = const Duration(seconds: 2);
    Object? lastError;

    while (attempt < maxAttempts) {
      try {
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
          ])
        ]);

        final raw = response.text?.trim();
        if (raw == null || raw.isEmpty) {
          throw Exception('Empty response from model.');
        }

        // Clean any stray markdown fences that may appear.
        final cleaned = raw
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final decoded = jsonDecode(cleaned);
        return DetectionResult.fromJson(decoded);
      } catch (e) {
        lastError = e;
        final msg = e.toString().toLowerCase();
        if (msg.contains('unavailable') ||
            msg.contains('quota') ||
            msg.contains('rate limit') ||
            msg.contains('network')) {
          await Future.delayed(backoff);
          backoff *= 2;
          attempt++;
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
        'Model calls failed after $maxAttempts attempts. Last error: $lastError');
  }

  static String _getMimeType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}