class DetectionResult {
  final bool isIdCard;
  final double confidence;
  final String documentType;
  final Map<String, String> extractedDetails;
  final String reasoning;

  DetectionResult({
    required this.isIdCard,
    required this.confidence,
    required this.documentType,
    required this.extractedDetails,
    required this.reasoning,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    // Safely extract details
    final detailsMap = <String, String>{};
    if (json['extracted_details'] is Map) {
      (json['extracted_details'] as Map).forEach((key, value) {
        detailsMap[key.toString()] = value?.toString() ?? 'N/A';
      });
    }

    return DetectionResult(
      isIdCard: json['is_id_card'] ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      documentType: json['document_type'] ?? 'Unknown',
      extractedDetails: detailsMap,
      reasoning: json['reasoning'] ?? '',
    );
  }

  factory DetectionResult.mockId() {
    return DetectionResult(
      isIdCard: true,
      confidence: 0.98,
      documentType: 'National ID Card',
      extractedDetails: {
        'full_name': 'John Doe',
        'id_number': 'ID-987654321-US',
        'issuing_country': 'United States',
        'date_of_birth': '1990-01-15',
        'expiry_date': '2030-05-20',
      },
      reasoning: 'Demo Mode: The document displays typical features of a standard National ID card, including a clear photo placeholder, personal details layout, and national emblem.',
    );
  }

  factory DetectionResult.mockNotId() {
    return DetectionResult(
      isIdCard: false,
      confidence: 0.95,
      documentType: 'Not an ID Card',
      extractedDetails: {},
      reasoning: 'Demo Mode: The image appears to be a landscape, a pet, or an object, and does not exhibit any characteristics of a formal identification document like text grids, official stamps, or portrait frames.',
    );
  }
}
