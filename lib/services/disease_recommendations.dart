/// Service class for generating disease-based treatment recommendations.
/// Supports multiple diseases per plant and returns deduplicated recommendations.
class DiseaseRecommendations {
  /// Disease-specific treatment recommendations mapping.
  static final Map<String, List<String>> _diseaseRecommendations = {
    'healthy': [
      'Maintain current care routine',
      'Continue regular monitoring',
      'Apply balanced fertilizer monthly',
      'Ensure adequate water drainage',
    ],
    'black sigatoka': [
      'Remove and destroy infected leaves immediately',
      'Apply systemic fungicide (Propiconazole or Azoxystrobin)',
      'Improve air circulation by pruning adjacent plants',
      'Apply treatment every 2-3 weeks during wet season',
      'Ensure proper spacing between plants',
    ],
    'panama': [
      'CRITICAL: Remove infected plant to prevent spread',
      'Disinfect all tools used near infected plant',
      'Do not replant in the same location for 2-3 years',
      'Apply soil fumigation before replanting',
      'Monitor nearby plants weekly for symptoms',
    ],
    'bract mosaic virus': [
      'Remove and destroy infected plant immediately',
      'Control aphid populations (virus vectors)',
      'Use virus-free planting material only',
      'Disinfect tools between plants',
      'Maintain 2-meter buffer zone around removal site',
    ],
    'cordana': [
      'Remove affected leaves and dispose properly',
      'Apply copper-based fungicide every 10-14 days',
      'Reduce leaf wetness duration',
      'Improve drainage around plant base',
      'Avoid overhead irrigation',
    ],
    'pestalotiopsis': [
      'Prune and remove affected plant parts',
      'Apply broad-spectrum fungicide',
      'Reduce plant stress through proper watering',
      'Apply balanced fertilizer to boost immunity',
      'Monitor weekly and retreat if symptoms persist',
    ],
  };

  /// Generic recommendations used when disease type is unknown.
  static const List<String> _genericRecommendations = [
    'Consult with agricultural extension officer',
    'Remove affected plant parts',
    'Apply appropriate fungicide or treatment',
    'Monitor plant closely for changes',
    'Ensure proper cultural practices',
  ];

  /// Get recommendations for a list of disease types.
  /// Returns deduplicated recommendations combined from all detected diseases.
  ///
  /// [diseaseTypes] - List of disease type strings detected on the plant.
  /// Returns a list of unique recommendation strings.
  static List<String> getRecommendationsForDiseases(List<String> diseaseTypes) {
    if (diseaseTypes.isEmpty) {
      return List.from(_genericRecommendations);
    }

    final Set<String> uniqueRecommendations = {};
    bool hasMatchedDisease = false;

    for (final diseaseType in diseaseTypes) {
      final disease = diseaseType.toLowerCase();

      // Check each known disease
      for (final entry in _diseaseRecommendations.entries) {
        if (disease.contains(entry.key)) {
          uniqueRecommendations.addAll(entry.value);
          hasMatchedDisease = true;
        }
      }
    }

    // If no diseases matched, return generic recommendations
    if (!hasMatchedDisease) {
      return List.from(_genericRecommendations);
    }

    return uniqueRecommendations.toList();
  }

  /// Get recommendations for a single disease type.
  /// Convenience method that wraps [getRecommendationsForDiseases].
  static List<String> getRecommendationsForDisease(String diseaseType) {
    return getRecommendationsForDiseases([diseaseType]);
  }
}
