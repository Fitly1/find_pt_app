// lib/services/fitly_match_engine.dart
import 'dart:math' as math;

class FitlyMatchUnavailableReason {
  static const String notSignedIn = 'not_signed_in';
  static const String customerQuizMissing = 'customer_quiz_missing';
  static const String trainerQuizMissing = 'trainer_quiz_missing';
}

class FitlyMatchResult {
  final bool available;
  final int score;
  final String label;
  final String title;
  final String message;
  final List<String> reasons;

  /// Lets the UI decide what to show.
  ///
  /// Example:
  /// - customer_quiz_missing -> show customer quiz prompt
  /// - trainer_quiz_missing -> hide from customers, prompt trainer privately
  final String? unavailableReason;

  const FitlyMatchResult({
    required this.available,
    required this.score,
    required this.label,
    required this.title,
    required this.message,
    required this.reasons,
    this.unavailableReason,
  });

  factory FitlyMatchResult.unavailable({
    required String title,
    required String message,
    required String reason,
  }) {
    return FitlyMatchResult(
      available: false,
      score: 0,
      label: 'Unavailable',
      title: title,
      message: message,
      reasons: const [],
      unavailableReason: reason,
    );
  }
}

class FitlyMatchEngine {
  const FitlyMatchEngine._();

  static FitlyMatchResult calculate({
    required Map<String, dynamic>? customerUserData,
    required Map<String, dynamic> trainerProfileData,
  }) {
    final customerIdentity = _mapFrom(customerUserData?['fitnessIdentityV2']);
    final trainerIdentity =
        _mapFrom(trainerProfileData['trainerFitnessIdentityV1']);

    if (customerUserData == null) {
      return FitlyMatchResult.unavailable(
        title: 'See your match',
        message:
            'Sign in and complete your fitness identity quiz to see compatibility.',
        reason: FitlyMatchUnavailableReason.notSignedIn,
      );
    }

    if (customerIdentity == null || customerIdentity.isEmpty) {
      return FitlyMatchResult.unavailable(
        title: 'See your match',
        message:
            'Complete your fitness identity quiz to see how well this trainer fits you.',
        reason: FitlyMatchUnavailableReason.customerQuizMissing,
      );
    }

    final trainerKey = _trainerKeyFromIdentity(trainerIdentity);

    if (trainerIdentity == null ||
        trainerIdentity.isEmpty ||
        trainerKey.isEmpty) {
      return FitlyMatchResult.unavailable(
        title: 'Match not ready',
        message: 'This trainer has not completed their coaching identity yet.',
        reason: FitlyMatchUnavailableReason.trainerQuizMissing,
      );
    }

    final customerDimensions = _mapFrom(customerIdentity['matchDimensions']) ??
        _mapFrom(customerIdentity['customerMatchDimensions']) ??
        const <String, dynamic>{};

    final trainerDimensions = _mapFrom(trainerIdentity['matchDimensions']) ??
        _mapFrom(trainerIdentity['trainerMatchDimensions']) ??
        const <String, dynamic>{};

    final dimensionScore = _dimensionScore(
      customerDimensions: customerDimensions,
      trainerDimensions: trainerDimensions,
    );

    final communicationScore = _communicationScore(
      customerDimensions: customerDimensions,
      trainerDimensions: trainerDimensions,
    );

    final archetypeScore = _archetypeScore(
      customerIdentity: customerIdentity,
      trainerIdentity: trainerIdentity,
    );

    final goalScore = _goalScore(
      customerIdentity: customerIdentity,
      trainerProfileData: trainerProfileData,
    );

    final weightedScores = <_WeightedScore>[
      if (dimensionScore != null) _WeightedScore(dimensionScore, 0.48),
      if (communicationScore != null) _WeightedScore(communicationScore, 0.22),
      _WeightedScore(archetypeScore, 0.20),
      _WeightedScore(goalScore, 0.10),
    ];

    final totalWeight =
        weightedScores.fold<double>(0, (sum, item) => sum + item.weight);

    final baseScore = totalWeight <= 0
        ? 0.0
        : weightedScores.fold<double>(
              0,
              (sum, item) => sum + (item.score * item.weight),
            ) /
            totalWeight;

    final penalty = _mismatchPenalty(
      customerDimensions: customerDimensions,
      trainerDimensions: trainerDimensions,
    );

    final finalScore = _clamp(baseScore - penalty, 0, 100).round();

    final reasons = _matchReasons(
      score: finalScore,
      customerIdentity: customerIdentity,
      trainerIdentity: trainerIdentity,
      customerDimensions: customerDimensions,
      trainerDimensions: trainerDimensions,
    );

    return FitlyMatchResult(
      available: true,
      score: finalScore,
      label: _scoreLabel(finalScore),
      title: '$finalScore% match',
      message: 'Based on your identity quiz and this trainer’s coaching style.',
      reasons: reasons,
    );
  }

  static double? _dimensionScore({
    required Map<String, dynamic> customerDimensions,
    required Map<String, dynamic> trainerDimensions,
  }) {
    final scores = <_WeightedScore?>[
      _needSupply(
        customerDimensions,
        'confidenceNeed',
        trainerDimensions,
        const ['supportWarmth', 'beginnerFriendliness'],
        1.2,
      ),
      _needSupply(
        customerDimensions,
        'beginnerSupportNeed',
        trainerDimensions,
        const ['beginnerFriendliness', 'supportWarmth'],
        1.1,
      ),
      _needSupply(
        customerDimensions,
        'structureNeed',
        trainerDimensions,
        const ['programStructure'],
        1.1,
      ),
      _needSupply(
        customerDimensions,
        'accountabilityNeed',
        trainerDimensions,
        const ['accountabilitySystem'],
        1.0,
      ),
      _needSupply(
        customerDimensions,
        'technicalCoachingNeed',
        trainerDimensions,
        const ['technicalCoaching', 'explanationDetail'],
        1.0,
      ),
      _needSupply(
        customerDimensions,
        'aestheticFocus',
        trainerDimensions,
        const ['aestheticCoaching'],
        0.85,
      ),
      _needSupply(
        customerDimensions,
        'strengthFocus',
        trainerDimensions,
        const ['strengthProgression'],
        0.85,
      ),
      _needSupply(
        customerDimensions,
        'lifestyleFlexibilityNeed',
        trainerDimensions,
        const ['lifestyleAdaptability'],
        0.95,
      ),
      _needSupply(
        customerDimensions,
        'autonomyPreference',
        trainerDimensions,
        const ['autonomySupport'],
        0.75,
      ),
    ].whereType<_WeightedScore>().toList();

    return _weightedAverage(scores);
  }

  static double? _communicationScore({
    required Map<String, dynamic> customerDimensions,
    required Map<String, dynamic> trainerDimensions,
  }) {
    final scores = <_WeightedScore?>[
      _needSupply(
        customerDimensions,
        'communicationWarmthNeed',
        trainerDimensions,
        const ['supportWarmth', 'feedbackSensitivity'],
        1.25,
      ),
      _needSupply(
        customerDimensions,
        'correctionSensitivity',
        trainerDimensions,
        const ['feedbackSensitivity', 'supportWarmth'],
        1.15,
      ),
      _needSupply(
        customerDimensions,
        'detailPreference',
        trainerDimensions,
        const ['explanationDetail'],
        0.85,
      ),
      _ceiling(
        customerDimensions,
        'directnessTolerance',
        trainerDimensions,
        const ['directnessLevel'],
        1.0,
      ),
      _ceiling(
        customerDimensions,
        'intensityTolerance',
        trainerDimensions,
        const ['intensityPush'],
        1.0,
      ),
    ].whereType<_WeightedScore>().toList();

    return _weightedAverage(scores);
  }

  static double _archetypeScore({
    required Map<String, dynamic> customerIdentity,
    required Map<String, dynamic> trainerIdentity,
  }) {
    final trainerKey = _trainerKeyFromIdentity(trainerIdentity);

    final recommendedStyles =
        _mapFrom(customerIdentity['recommendedTrainerStyles']);

    final primaryRaw = recommendedStyles?['primary'];
    final secondaryRaw = recommendedStyles?['secondary'];

    dynamic primaryValue =
        customerIdentity['customerRecommendedTrainerStyleId'];
    if (primaryRaw is Map) {
      primaryValue = _mapFrom(primaryRaw)?['id'];
    }

    dynamic secondaryValue =
        customerIdentity['customerSecondaryTrainerStyleId'];
    if (secondaryRaw is Map) {
      secondaryValue = _mapFrom(secondaryRaw)?['id'];
    }

    final primary = _normaliseKey(primaryValue);
    final secondary = _normaliseKey(secondaryValue);

    if (trainerKey.isNotEmpty && primary.isNotEmpty && trainerKey == primary) {
      return 100;
    }

    if (trainerKey.isNotEmpty &&
        secondary.isNotEmpty &&
        trainerKey == secondary) {
      return 84;
    }

    final customerKey = _normaliseKey(
      customerIdentity['archetypeId'] ??
          customerIdentity['key'] ??
          customerIdentity['fitnessIdentity'],
    );

    const matrix = <String, List<String>>{
      'the_comeback': ['the_guide', 'the_anchor', 'the_builder'],
      'the_momentum': ['the_builder', 'the_anchor', 'the_guide'],
      'the_strong': ['the_builder', 'the_challenger', 'the_guide'],
      'the_glow_up': ['the_sculptor', 'the_builder', 'the_guide'],
      'the_glowup': ['the_sculptor', 'the_builder', 'the_guide'],
      'the_edge': ['the_challenger', 'the_builder', 'the_sculptor'],
      'the_balance': ['the_anchor', 'the_guide', 'the_builder'],
      'the_ascent': ['the_challenger', 'the_builder', 'the_sculptor'],
      'the_pulse': ['the_anchor', 'the_challenger', 'the_builder'],
    };

    final ranked = matrix[customerKey] ?? const <String>[];

    if (ranked.isEmpty || trainerKey.isEmpty) return 68;

    final index = ranked.indexOf(trainerKey);

    if (index == 0) return 94;
    if (index == 1) return 82;
    if (index == 2) return 74;

    return 58;
  }

  static double _goalScore({
    required Map<String, dynamic> customerIdentity,
    required Map<String, dynamic> trainerProfileData,
  }) {
    final customerDimensions = _mapFrom(customerIdentity['matchDimensions']) ??
        const <String, dynamic>{};

    final specialties = (trainerProfileData['specialties'] is List)
        ? (trainerProfileData['specialties'] as List)
            .map((item) => item.toString().toLowerCase())
            .toSet()
        : <String>{};

    if (specialties.isEmpty) return 64;

    final aesthetic = _value(customerDimensions, 'aestheticFocus') ?? 0;
    final strength = _value(customerDimensions, 'strengthFocus') ?? 0;

    double score = 64;

    if (aesthetic >= 55) {
      if (specialties.contains('weight loss') ||
          specialties.contains('pilates') ||
          specialties.contains('strength training')) {
        score += 18;
      }
    }

    if (strength >= 55) {
      if (specialties.contains('strength training') ||
          specialties.contains('crossfit') ||
          specialties.contains('hiit')) {
        score += 18;
      }
    }

    final customerKey = _normaliseKey(
      customerIdentity['archetypeId'] ?? customerIdentity['key'],
    );

    if (customerKey == 'the_balance' && specialties.contains('yoga')) {
      score += 12;
    }

    if (customerKey == 'the_edge' &&
        (specialties.contains('hiit') || specialties.contains('crossfit'))) {
      score += 12;
    }

    return _clamp(score, 45, 100);
  }

  static double _mismatchPenalty({
    required Map<String, dynamic> customerDimensions,
    required Map<String, dynamic> trainerDimensions,
  }) {
    final correctionSensitivity =
        _value(customerDimensions, 'correctionSensitivity') ?? 0;
    final warmthNeed =
        _value(customerDimensions, 'communicationWarmthNeed') ?? 0;
    final intensityTolerance =
        _value(customerDimensions, 'intensityTolerance') ?? 50;
    final directnessTolerance =
        _value(customerDimensions, 'directnessTolerance') ?? 50;

    final intensityPush = _value(trainerDimensions, 'intensityPush') ?? 50;
    final directness = _value(trainerDimensions, 'directnessLevel') ?? 50;
    final warmth = _averageValues(
          trainerDimensions,
          const ['supportWarmth', 'feedbackSensitivity'],
        ) ??
        50;

    double penalty = 0;

    if (correctionSensitivity >= 70 && directness >= 75) penalty += 7;
    if (warmthNeed >= 70 && warmth < 50) penalty += 7;
    if (intensityPush - intensityTolerance > 25) penalty += 8;
    if (directness - directnessTolerance > 25) penalty += 6;

    return _clamp(penalty, 0, 20);
  }

  static List<String> _matchReasons({
    required int score,
    required Map<String, dynamic> customerIdentity,
    required Map<String, dynamic> trainerIdentity,
    required Map<String, dynamic> customerDimensions,
    required Map<String, dynamic> trainerDimensions,
  }) {
    final reasons = <String>[];

    final trainerTitle =
        (trainerIdentity['archetypeName'] ?? 'this trainer').toString();

    final customerRecommended = _archetypeScore(
      customerIdentity: customerIdentity,
      trainerIdentity: trainerIdentity,
    );

    if (customerRecommended >= 84) {
      reasons.add(
        '$trainerTitle fits one of your strongest coaching style matches.',
      );
    }

    final structureNeed = _value(customerDimensions, 'structureNeed') ?? 0;
    final programStructure = _value(trainerDimensions, 'programStructure') ?? 0;
    if (structureNeed >= 55 && programStructure >= 55) {
      reasons.add(
        'Their coaching style supports structure, routine, and progression.',
      );
    }

    final warmthNeed =
        _value(customerDimensions, 'communicationWarmthNeed') ?? 0;
    final warmth = _averageValues(
          trainerDimensions,
          const ['supportWarmth', 'feedbackSensitivity'],
        ) ??
        0;
    if (warmthNeed >= 55 && warmth >= 55) {
      reasons.add(
        'Their communication style should feel supportive and easier to work with.',
      );
    }

    final intensityTolerance =
        _value(customerDimensions, 'intensityTolerance') ?? 50;
    final intensityPush = _value(trainerDimensions, 'intensityPush') ?? 50;
    if (intensityTolerance >= 60 && intensityPush >= 60) {
      reasons.add(
        'You may respond well to their level of challenge and intensity.',
      );
    }

    final lifestyleNeed =
        _value(customerDimensions, 'lifestyleFlexibilityNeed') ?? 0;
    final lifestyleAdaptability =
        _value(trainerDimensions, 'lifestyleAdaptability') ?? 0;
    if (lifestyleNeed >= 55 && lifestyleAdaptability >= 55) {
      reasons.add(
        'They appear suited to clients who need fitness to fit real life.',
      );
    }

    if (reasons.isEmpty) {
      reasons.add(
        score >= 70
            ? 'Your quiz signals and this trainer’s coaching profile are generally aligned.'
            : 'Some areas match, but check their style, rate, and availability before deciding.',
      );
    }

    return reasons.take(3).toList();
  }

  static _WeightedScore? _needSupply(
    Map<String, dynamic> customer,
    String customerKey,
    Map<String, dynamic> trainer,
    List<String> trainerKeys,
    double weight,
  ) {
    final need = _value(customer, customerKey);
    final supply = _averageValues(trainer, trainerKeys);

    if (need == null || supply == null) return null;

    final shortfall = math.max(0, need - supply);
    final surplus = math.max(0, supply - need);
    final score = 100 - (shortfall * 0.9) - (surplus * 0.18);

    return _WeightedScore(_clamp(score, 0, 100), weight);
  }

  static _WeightedScore? _ceiling(
    Map<String, dynamic> customer,
    String customerKey,
    Map<String, dynamic> trainer,
    List<String> trainerKeys,
    double weight,
  ) {
    final tolerance = _value(customer, customerKey);
    final level = _averageValues(trainer, trainerKeys);

    if (tolerance == null || level == null) return null;

    final over = math.max(0, level - tolerance);
    final under = math.max(0, tolerance - level);
    final score = 100 - (over * 0.95) - (under * 0.22);

    return _WeightedScore(_clamp(score, 0, 100), weight);
  }

  static double? _weightedAverage(List<_WeightedScore> scores) {
    if (scores.isEmpty) return null;

    final totalWeight =
        scores.fold<double>(0, (sum, item) => sum + item.weight);
    if (totalWeight <= 0) return null;

    return scores.fold<double>(
          0,
          (sum, item) => sum + (item.score * item.weight),
        ) /
        totalWeight;
  }

  static double? _averageValues(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    final values =
        keys.map((key) => _value(map, key)).whereType<double>().toList();

    if (values.isEmpty) return null;

    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? _value(Map<String, dynamic> map, String key) {
    final raw = map[key];

    if (raw == null) return null;

    double? value;

    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw);
    }

    if (value == null) return null;

    if (value <= 1) return _clamp(value * 100, 0, 100);
    if (value <= 10) return _clamp(value * 10, 0, 100);

    return _clamp(value, 0, 100);
  }

  static String _trainerKeyFromIdentity(Map<String, dynamic>? identity) {
    if (identity == null) return '';

    return _normaliseKey(
      identity['archetypeId'] ?? identity['key'] ?? identity['trainerIdentity'],
    );
  }

  static Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _normaliseKey(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return '';

    final cleaned = raw
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (cleaned.startsWith('the_')) return cleaned;

    return 'the_$cleaned';
  }

  static String _scoreLabel(int score) {
    if (score >= 85) return 'Excellent match';
    if (score >= 75) return 'Strong match';
    if (score >= 65) return 'Good match';
    if (score >= 55) return 'Possible match';
    return 'Low match';
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

class _WeightedScore {
  final double score;
  final double weight;

  const _WeightedScore(this.score, this.weight);
}
