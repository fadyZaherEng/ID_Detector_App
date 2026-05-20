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

  static Future<DetectionResult> detectIdCardLocally({required File imageFile}) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text;
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
                           lowerText.contains('بطاقة');
                           
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
        reasoning = 'Local ML Kit OCR scanned the image and successfully identified key text structures indicating a $docType. This verification was processed 100% locally on the device.';
        
        // Extract 14-digit Egyptian ID if exists
        final egyptIdRegex = RegExp(r'\b\d{14}\b');
        final matchId = egyptIdRegex.firstMatch(text);
        if (matchId != null) {
          details['id_number'] = matchId.group(0)!;
        }

        // Extract potential date values (YYYY-MM-DD or DD/MM/YYYY)
        final dateRegex = RegExp(r'\b\d{2}[-/.]\d{2}[-/.]\d{4}\b|\b\d{4}[-/.]\d{2}[-/.]\d{2}\b');
        final dates = dateRegex.allMatches(text).map((m) => m.group(0)!).toList();
        if (dates.isNotEmpty) {
          details['dates_found'] = dates.join(', ');
        }
        
        // Include first 100 characters of scanned text
        final snippet = text.replaceAll('\n', ' ').trim();
        details['scanned_text'] = snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet;
      } else {
        reasoning = 'Local ML Kit OCR scanned the image but could not find any typical text indicators matching a National ID, Passport, or Driver\'s License. No government headers or standard ID patterns were detected.';
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
