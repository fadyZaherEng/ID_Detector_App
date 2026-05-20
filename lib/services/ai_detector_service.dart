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
      'gemini-3.1-flash-lite',
      'gemini-3.5-flash',
    ];

    Object? lastError;

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

        final imageBytes = await imageFile.readAsBytes();
        final mimeType = _getMimeType(imageFile.path);

        const prompt = '''
        Analyze the provided image and determine if it is an official identification document. 
        Official identification documents include: National ID Cards, Passports, Driver's Licenses, State IDs, Resident Cards, or similar government-issued photo identification.
        
        Return a JSON object with the following fields:
        - is_id_card: a boolean indicating if the image is an identification document.
        - confidence: a double between 0.0 and 1.0 representing your confidence in this decision.
        - document_type: a string specifying the type of document (e.g., "National ID", "Driver's License", "Passport", "Resident Card", "Not an ID Card", "Unknown").
        - extracted_details: a JSON object containing key-value pairs of any details you can read from the document, such as:
          - full_name
          - id_number
          - expiry_date
          - issuing_country
          - date_of_birth
          - any other relevant fields visible (use lowercase snake_case for keys, and string values). If not an ID or no details can be read, leave this object empty.
        - reasoning: a string explaining the reason for your classification (e.g., "Contains a clear face photograph, government markings, and typical ID card metadata fields" or "This is a photo of a dog and contains no identification card properties").

        Do not include any formatting other than the raw JSON output.
        ''';

        final response = await model.generateContent([
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ])
        ]);

        final responseText = response.text;
        if (responseText == null) {
          throw Exception('Received empty response from Gemini AI.');
        }

        final decoded = jsonDecode(responseText);
        return DetectionResult.fromJson(decoded);
      } catch (e) {
        lastError = e;
        // Print warning to log and try next model
        print('Model $modelName failed with error: $e. Trying fallback model...');
      }
    }

    throw Exception('All Gemini models failed. Last error: $lastError');
  }

  static String _getMimeType(String filePath) {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    } else if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    } else if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg'; // default fallback
  }
}
