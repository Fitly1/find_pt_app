// lib/customer_quiz_page.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);

class CustomerQuizPage extends StatefulWidget {
  const CustomerQuizPage({super.key});

  @override
  State<CustomerQuizPage> createState() => _CustomerQuizPageState();
}

/* ───────────────── Result model ───────────────── */

class _BadgeResult {
  final String key;
  final String title;
  final String tagline;
  final String shortMeaning;
  final String trainerMatch;
  final String assetPath;
  final Color accent;
  final IconData fallbackIcon;

  final String blindSpotTitle;
  final String blindSpotDescription;
  final String bestTrainerStyleId;
  final String bestTrainerStyleName;
  final String secondaryTrainerStyleId;
  final String secondaryTrainerStyleName;

  const _BadgeResult({
    required this.key,
    required this.title,
    required this.tagline,
    required this.shortMeaning,
    required this.trainerMatch,
    required this.assetPath,
    required this.accent,
    required this.fallbackIcon,
    required this.blindSpotTitle,
    required this.blindSpotDescription,
    required this.bestTrainerStyleId,
    required this.bestTrainerStyleName,
    required this.secondaryTrainerStyleId,
    required this.secondaryTrainerStyleName,
  });
}

class _TrainerStylePreview {
  final String id;
  final String name;
  final String description;

  const _TrainerStylePreview({
    required this.id,
    required this.name,
    required this.description,
  });
}

/*
  Final locked customer identities:
  1. The Comeback
  2. The Momentum
  3. The Strong
  4. The Glow-Up
  5. The Edge
  6. The Balance

  The old identities are no longer active in this quiz:
  - The Ascent
  - The Pulse
  - The Forge

  Keep old identity support inside the display card only if you need backward
  compatibility for users who already completed an older quiz.
*/
const Map<String, _BadgeResult> _badgeResults = {
  'the_comeback': _BadgeResult(
    key: 'the_comeback',
    title: 'The Comeback',
    tagline: 'Built to begin again.',
    shortMeaning:
        'You are rebuilding momentum. You work best with confidence, patience, small wins, and steady support.',
    trainerMatch:
        'Best with The Guide — a supportive trainer who helps you restart without judgement.',
    assetPath: 'assets/badges/customers/the_comeback.png',
    accent: Color(0xFFB64A42),
    fallbackIcon: Icons.restart_alt_rounded,
    blindSpotTitle: 'The Too-Much-Too-Soon Trap',
    blindSpotDescription:
        'You may try to make up for lost time, then burn out quickly. The right trainer helps you rebuild steadily.',
    bestTrainerStyleId: 'the_guide',
    bestTrainerStyleName: 'The Guide',
    secondaryTrainerStyleId: 'the_anchor',
    secondaryTrainerStyleName: 'The Anchor',
  ),
  'the_momentum': _BadgeResult(
    key: 'the_momentum',
    title: 'The Momentum',
    tagline: 'Built for rhythm, not random motivation.',
    shortMeaning:
        'You work best with rhythm, routine, accountability, and clear weekly progress.',
    trainerMatch:
        'Best with The Builder — a structured trainer who keeps you consistent and moving forward.',
    assetPath: 'assets/badges/customers/the_momentum.png',
    accent: Color(0xFF3A6FD8),
    fallbackIcon: Icons.trending_up_rounded,
    blindSpotTitle: 'The Week 3 Fade',
    blindSpotDescription:
        'You can start strong, but when life breaks your rhythm, it can be hard to restart. The right trainer protects your routine.',
    bestTrainerStyleId: 'the_builder',
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleId: 'the_guide',
    secondaryTrainerStyleName: 'The Guide',
  ),
  'the_strong': _BadgeResult(
    key: 'the_strong',
    title: 'The Strong',
    tagline: 'Built to feel capable.',
    shortMeaning:
        'You are driven by strength, capability, form, progression, and feeling powerful in your body.',
    trainerMatch:
        'Best with The Builder — a trainer who teaches technique, structure, and measurable progression.',
    assetPath: 'assets/badges/customers/the_strong.png',
    accent: Color(0xFF9B7A42),
    fallbackIcon: Icons.fitness_center_rounded,
    blindSpotTitle: 'The Comfort-Zone Plateau',
    blindSpotDescription:
        'You may repeat what feels familiar instead of progressing. The right trainer gives you form, structure, and next steps.',
    bestTrainerStyleId: 'the_builder',
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleId: 'the_challenger',
    secondaryTrainerStyleName: 'The Challenger',
  ),
  'the_glow_up': _BadgeResult(
    key: 'the_glow_up',
    title: 'The Glow-Up',
    tagline: 'Built to feel good in your own skin.',
    shortMeaning:
        'You care about visible change, confidence, body composition, and feeling better in clothes, photos, and social situations.',
    trainerMatch:
        'Best with The Sculptor — a trainer who understands visible progress without making it unhealthy or obsessive.',
    assetPath: 'assets/badges/customers/the_glow_up.png',
    accent: Color(0xFFE6A0B7),
    fallbackIcon: Icons.auto_awesome_rounded,
    blindSpotTitle: 'The Mirror Check Spiral',
    blindSpotDescription:
        'You may judge progress too quickly by what you see day to day. The right trainer keeps you focused on real change over time.',
    bestTrainerStyleId: 'the_sculptor',
    bestTrainerStyleName: 'The Sculptor',
    secondaryTrainerStyleId: 'the_builder',
    secondaryTrainerStyleName: 'The Builder',
  ),
  'the_edge': _BadgeResult(
    key: 'the_edge',
    title: 'The Edge',
    tagline: 'Built to chase the next level.',
    shortMeaning:
        'You respond to challenge, intensity, competitiveness, high standards, and being pushed with purpose.',
    trainerMatch:
        'Best with The Challenger — a direct trainer who raises the standard and pushes your limits safely.',
    assetPath: 'assets/badges/customers/the_edge.png',
    accent: Color(0xFFD97935),
    fallbackIcon: Icons.bolt_rounded,
    blindSpotTitle: 'The Always-On Trap',
    blindSpotDescription:
        'You may push hard even when recovery or patience would help more. The right trainer challenges you without letting you overdo it.',
    bestTrainerStyleId: 'the_challenger',
    bestTrainerStyleName: 'The Challenger',
    secondaryTrainerStyleId: 'the_sculptor',
    secondaryTrainerStyleName: 'The Sculptor',
  ),
  'the_balance': _BadgeResult(
    key: 'the_balance',
    title: 'The Balance',
    tagline: 'Built for real life.',
    shortMeaning:
        'You need sustainable training, calm structure, recovery, health, and a plan that fits your actual life.',
    trainerMatch:
        'Best with The Anchor — a calm trainer who makes fitness realistic, steady, and sustainable.',
    assetPath: 'assets/badges/customers/the_balance.png',
    accent: Color(0xFF4FAFA3),
    fallbackIcon: Icons.balance_rounded,
    blindSpotTitle: 'The Last-on-the-List Trap',
    blindSpotDescription:
        'You may put training behind work, stress, and everyone else’s needs. The right trainer helps fitness fit your life instead of fighting it.',
    bestTrainerStyleId: 'the_anchor',
    bestTrainerStyleName: 'The Anchor',
    secondaryTrainerStyleId: 'the_guide',
    secondaryTrainerStyleName: 'The Guide',
  ),
};

const Map<String, _TrainerStylePreview> _trainerStyles = {
  'the_guide': _TrainerStylePreview(
    id: 'the_guide',
    name: 'The Guide',
    description:
        'Supportive, patient, confidence-building, and beginner-friendly.',
  ),
  'the_builder': _TrainerStylePreview(
    id: 'the_builder',
    name: 'The Builder',
    description:
        'Structured, accountable, consistent, and progression-focused.',
  ),
  'the_sculptor': _TrainerStylePreview(
    id: 'the_sculptor',
    name: 'The Sculptor',
    description: 'Focused on visible change, body composition, and confidence.',
  ),
  'the_challenger': _TrainerStylePreview(
    id: 'the_challenger',
    name: 'The Challenger',
    description: 'Direct, intense, performance-driven, and standards-focused.',
  ),
  'the_anchor': _TrainerStylePreview(
    id: 'the_anchor',
    name: 'The Anchor',
    description: 'Calm, sustainable, realistic, and lifestyle-aware.',
  ),
};

const List<String> _dimensionKeys = [
  // Confidence / comfort
  'confidenceNeed',
  'beginnerSupportNeed',

  // Behaviour change / consistency
  'structureNeed',
  'accountabilityNeed',
  'lifestyleFlexibilityNeed',
  'autonomyPreference',

  // Coaching intensity
  'intensityTolerance',

  // Communication fit
  'communicationWarmthNeed',
  'directnessTolerance',
  'detailPreference',
  'correctionSensitivity',

  // Training outcome / coaching type
  'technicalCoachingNeed',
  'aestheticFocus',
  'strengthFocus',
];

const List<String> _trainerBiasKeys = [
  'the_guide',
  'the_builder',
  'the_sculptor',
  'the_challenger',
  'the_anchor',
];

/* ───────────────── Quiz models ───────────────── */

class _QuizQuestion {
  final String id;
  final String question;
  final String subtitle;
  final List<_QuizOption> options;

  const _QuizQuestion({
    required this.id,
    required this.question,
    required this.subtitle,
    required this.options,
  });
}

class _QuizOption {
  final String label;
  final IconData icon;
  final Map<String, int> scores;
  final Map<String, int> dimensions;
  final Map<String, int> trainerBias;

  const _QuizOption({
    required this.label,
    required this.icon,
    required this.scores,
    this.dimensions = const {},
    this.trainerBias = const {},
  });
}

const List<_QuizQuestion> _questions = [
  _QuizQuestion(
    id: 'starting_point',
    question: 'Where are you starting from?',
    subtitle: 'Pick the one that feels closest right now.',
    options: [
      _QuizOption(
        label: 'Restarting after falling off',
        icon: Icons.restart_alt_rounded,
        scores: {
          'the_comeback': 4,
          'the_balance': 1,
        },
        dimensions: {
          'confidenceNeed': 5,
          'beginnerSupportNeed': 5,
          'structureNeed': 3,
          'communicationWarmthNeed': 3,
          'correctionSensitivity': 3,
          'intensityTolerance': 1,
        },
        trainerBias: {
          'the_guide': 4,
          'the_anchor': 2,
        },
      ),
      _QuizOption(
        label: 'Inconsistent and need rhythm',
        icon: Icons.calendar_month_rounded,
        scores: {
          'the_momentum': 4,
          'the_balance': 1,
        },
        dimensions: {
          'structureNeed': 5,
          'accountabilityNeed': 5,
          'lifestyleFlexibilityNeed': 3,
          'detailPreference': 2,
          'intensityTolerance': 2,
        },
        trainerBias: {
          'the_builder': 4,
          'the_guide': 2,
        },
      ),
      _QuizOption(
        label: 'Ready to get stronger',
        icon: Icons.fitness_center_rounded,
        scores: {
          'the_strong': 4,
          'the_edge': 1,
        },
        dimensions: {
          'strengthFocus': 5,
          'technicalCoachingNeed': 4,
          'structureNeed': 3,
          'detailPreference': 3,
          'directnessTolerance': 3,
          'intensityTolerance': 3,
        },
        trainerBias: {
          'the_builder': 4,
          'the_challenger': 2,
        },
      ),
      _QuizOption(
        label: 'Need fitness to fit my life',
        icon: Icons.balance_rounded,
        scores: {
          'the_balance': 4,
          'the_comeback': 1,
        },
        dimensions: {
          'lifestyleFlexibilityNeed': 5,
          'autonomyPreference': 4,
          'structureNeed': 3,
          'communicationWarmthNeed': 2,
          'intensityTolerance': 1,
        },
        trainerBias: {
          'the_anchor': 4,
          'the_guide': 2,
        },
      ),
    ],
  ),
  _QuizQuestion(
    id: 'primary_goal',
    question: 'What result matters most?',
    subtitle: 'This helps Fitly understand what you are really chasing.',
    options: [
      _QuizOption(
        label: 'Drop body fat and feel confident',
        icon: Icons.auto_awesome_rounded,
        scores: {
          'the_glow_up': 4,
          'the_momentum': 1,
        },
        dimensions: {
          'aestheticFocus': 5,
          'accountabilityNeed': 3,
          'structureNeed': 2,
          'confidenceNeed': 2,
          'communicationWarmthNeed': 2,
          'correctionSensitivity': 2,
        },
        trainerBias: {
          'the_sculptor': 4,
          'the_builder': 2,
        },
      ),
      _QuizOption(
        label: 'Build strength and capability',
        icon: Icons.fitness_center_rounded,
        scores: {
          'the_strong': 4,
          'the_edge': 1,
        },
        dimensions: {
          'strengthFocus': 5,
          'technicalCoachingNeed': 4,
          'structureNeed': 3,
          'detailPreference': 3,
          'intensityTolerance': 3,
        },
        trainerBias: {
          'the_builder': 4,
          'the_challenger': 2,
        },
      ),
      _QuizOption(
        label: 'Stay consistent week to week',
        icon: Icons.trending_up_rounded,
        scores: {
          'the_momentum': 4,
          'the_balance': 1,
        },
        dimensions: {
          'structureNeed': 5,
          'accountabilityNeed': 5,
          'lifestyleFlexibilityNeed': 2,
          'detailPreference': 2,
          'autonomyPreference': 2,
        },
        trainerBias: {
          'the_builder': 4,
          'the_guide': 2,
        },
      ),
      _QuizOption(
        label: 'Push harder and level up',
        icon: Icons.bolt_rounded,
        scores: {
          'the_edge': 4,
          'the_strong': 1,
        },
        dimensions: {
          'intensityTolerance': 5,
          'directnessTolerance': 4,
          'accountabilityNeed': 3,
          'strengthFocus': 3,
          'structureNeed': 2,
        },
        trainerBias: {
          'the_challenger': 4,
          'the_sculptor': 2,
        },
      ),
    ],
  ),
  _QuizQuestion(
    id: 'main_blocker',
    question: 'What usually breaks your progress?',
    subtitle: 'This is the hidden signal that makes matching more accurate.',
    options: [
      _QuizOption(
        label: 'I lose confidence quickly',
        icon: Icons.psychology_alt_rounded,
        scores: {
          'the_comeback': 4,
          'the_balance': 1,
        },
        dimensions: {
          'confidenceNeed': 5,
          'beginnerSupportNeed': 5,
          'communicationWarmthNeed': 4,
          'correctionSensitivity': 4,
          'directnessTolerance': 1,
          'intensityTolerance': 1,
          'structureNeed': 2,
        },
        trainerBias: {
          'the_guide': 5,
          'the_anchor': 2,
        },
      ),
      _QuizOption(
        label: 'I fall off after a few weeks',
        icon: Icons.sync_rounded,
        scores: {
          'the_momentum': 4,
          'the_balance': 1,
        },
        dimensions: {
          'structureNeed': 5,
          'accountabilityNeed': 5,
          'lifestyleFlexibilityNeed': 3,
          'detailPreference': 2,
          'autonomyPreference': 1,
        },
        trainerBias: {
          'the_builder': 5,
          'the_guide': 2,
        },
      ),
      _QuizOption(
        label: 'I judge progress too fast',
        icon: Icons.visibility_rounded,
        scores: {
          'the_glow_up': 4,
          'the_comeback': 1,
        },
        dimensions: {
          'aestheticFocus': 5,
          'confidenceNeed': 3,
          'communicationWarmthNeed': 3,
          'correctionSensitivity': 3,
          'accountabilityNeed': 3,
          'structureNeed': 2,
        },
        trainerBias: {
          'the_sculptor': 4,
          'the_builder': 2,
        },
      ),
      _QuizOption(
        label: 'Stress and life get in the way',
        icon: Icons.self_improvement_rounded,
        scores: {
          'the_balance': 4,
          'the_momentum': 1,
        },
        dimensions: {
          'lifestyleFlexibilityNeed': 5,
          'autonomyPreference': 4,
          'communicationWarmthNeed': 3,
          'structureNeed': 3,
          'intensityTolerance': 1,
        },
        trainerBias: {
          'the_anchor': 5,
          'the_guide': 2,
        },
      ),
    ],
  ),
  _QuizQuestion(
    id: 'support_need',
    question: 'What support would keep you going?',
    subtitle: 'Choose what you would actually respond to.',
    options: [
      _QuizOption(
        label: 'No judgement and small wins',
        icon: Icons.volunteer_activism_rounded,
        scores: {
          'the_comeback': 4,
          'the_balance': 1,
        },
        dimensions: {
          'confidenceNeed': 5,
          'beginnerSupportNeed': 5,
          'communicationWarmthNeed': 5,
          'correctionSensitivity': 4,
          'directnessTolerance': 1,
          'intensityTolerance': 1,
          'autonomyPreference': 3,
        },
        trainerBias: {
          'the_guide': 5,
          'the_anchor': 2,
        },
      ),
      _QuizOption(
        label: 'Clear plan and check-ins',
        icon: Icons.account_tree_rounded,
        scores: {
          'the_momentum': 4,
          'the_strong': 1,
        },
        dimensions: {
          'structureNeed': 5,
          'accountabilityNeed': 5,
          'detailPreference': 3,
          'technicalCoachingNeed': 2,
          'directnessTolerance': 3,
          'autonomyPreference': 1,
        },
        trainerBias: {
          'the_builder': 5,
          'the_guide': 2,
        },
      ),
      _QuizOption(
        label: 'Technique and exact guidance',
        icon: Icons.sports_gymnastics_rounded,
        scores: {
          'the_strong': 4,
          'the_momentum': 1,
        },
        dimensions: {
          'technicalCoachingNeed': 5,
          'detailPreference': 5,
          'strengthFocus': 5,
          'structureNeed': 4,
          'directnessTolerance': 3,
          'intensityTolerance': 3,
        },
        trainerBias: {
          'the_builder': 5,
          'the_challenger': 2,
        },
      ),
      _QuizOption(
        label: 'Honest body-change guidance',
        icon: Icons.insights_rounded,
        scores: {
          'the_glow_up': 4,
          'the_momentum': 1,
        },
        dimensions: {
          'aestheticFocus': 5,
          'accountabilityNeed': 4,
          'structureNeed': 3,
          'confidenceNeed': 2,
          'communicationWarmthNeed': 2,
          'detailPreference': 3,
        },
        trainerBias: {
          'the_sculptor': 5,
          'the_builder': 2,
        },
      ),
    ],
  ),
  _QuizQuestion(
    id: 'correction_style',
    question: 'When a trainer corrects you, what helps most?',
    subtitle:
        'This captures the communication style you will feel comfortable with.',
    options: [
      _QuizOption(
        label: 'Show me calmly and encourage me',
        icon: Icons.favorite_rounded,
        scores: {
          'the_comeback': 3,
          'the_balance': 2,
        },
        dimensions: {
          'communicationWarmthNeed': 5,
          'correctionSensitivity': 5,
          'confidenceNeed': 4,
          'beginnerSupportNeed': 3,
          'directnessTolerance': 1,
          'intensityTolerance': 1,
        },
        trainerBias: {
          'the_guide': 5,
          'the_anchor': 2,
        },
      ),
      _QuizOption(
        label: 'Give me clear steps and explain why',
        icon: Icons.format_list_numbered_rounded,
        scores: {
          'the_strong': 3,
          'the_momentum': 2,
        },
        dimensions: {
          'detailPreference': 5,
          'technicalCoachingNeed': 5,
          'structureNeed': 3,
          'directnessTolerance': 3,
          'communicationWarmthNeed': 2,
        },
        trainerBias: {
          'the_builder': 5,
          'the_guide': 1,
        },
      ),
      _QuizOption(
        label: 'Be direct with honest feedback',
        icon: Icons.campaign_rounded,
        scores: {
          'the_edge': 4,
          'the_strong': 1,
        },
        dimensions: {
          'directnessTolerance': 5,
          'intensityTolerance': 4,
          'accountabilityNeed': 3,
          'strengthFocus': 2,
          'correctionSensitivity': 1,
        },
        trainerBias: {
          'the_challenger': 5,
          'the_builder': 2,
        },
      ),
      _QuizOption(
        label: 'Keep it simple so I do not overthink',
        icon: Icons.lightbulb_outline_rounded,
        scores: {
          'the_glow_up': 3,
          'the_balance': 2,
        },
        dimensions: {
          'correctionSensitivity': 4,
          'communicationWarmthNeed': 3,
          'confidenceNeed': 3,
          'detailPreference': 1,
          'autonomyPreference': 3,
          'intensityTolerance': 2,
        },
        trainerBias: {
          'the_anchor': 4,
          'the_sculptor': 2,
        },
      ),
    ],
  ),
  _QuizQuestion(
    id: 'session_feel',
    question: 'What should a good session feel like?',
    subtitle: 'This helps match the trainer’s delivery style to your energy.',
    options: [
      _QuizOption(
        label: 'Calm, controlled, sustainable',
        icon: Icons.balance_rounded,
        scores: {
          'the_balance': 4,
          'the_comeback': 1,
        },
        dimensions: {
          'lifestyleFlexibilityNeed': 4,
          'autonomyPreference': 4,
          'communicationWarmthNeed': 2,
          'intensityTolerance': 1,
          'confidenceNeed': 2,
        },
        trainerBias: {
          'the_anchor': 5,
          'the_guide': 2,
        },
      ),
      _QuizOption(
        label: 'Structured and repeatable',
        icon: Icons.trending_up_rounded,
        scores: {
          'the_momentum': 4,
          'the_strong': 1,
        },
        dimensions: {
          'structureNeed': 5,
          'accountabilityNeed': 4,
          'detailPreference': 3,
          'technicalCoachingNeed': 2,
          'autonomyPreference': 1,
        },
        trainerBias: {
          'the_builder': 5,
          'the_guide': 1,
        },
      ),
      _QuizOption(
        label: 'Targeted and visual',
        icon: Icons.auto_graph_rounded,
        scores: {
          'the_glow_up': 4,
          'the_strong': 1,
        },
        dimensions: {
          'aestheticFocus': 5,
          'technicalCoachingNeed': 3,
          'detailPreference': 3,
          'structureNeed': 3,
          'accountabilityNeed': 3,
        },
        trainerBias: {
          'the_sculptor': 5,
          'the_builder': 2,
        },
      ),
      _QuizOption(
        label: 'Hard, sharp, and intense',
        icon: Icons.flash_on_rounded,
        scores: {
          'the_edge': 4,
          'the_strong': 1,
        },
        dimensions: {
          'intensityTolerance': 5,
          'directnessTolerance': 4,
          'strengthFocus': 3,
          'accountabilityNeed': 3,
          'structureNeed': 2,
        },
        trainerBias: {
          'the_challenger': 5,
          'the_sculptor': 2,
        },
      ),
    ],
  ),
];

class _CustomerQuizPageState extends State<CustomerQuizPage> {
  int _currentStep = 0;
  bool _saving = false;

  final Map<String, String> _answers = {};
  final Map<String, _QuizOption> _selectedOptions = {};

  double get _progress => (_currentStep + 1) / _questions.length;
  _QuizQuestion get _currentQuestion => _questions[_currentStep];

  void _selectOption(_QuizOption option) {
    if (_saving) return;

    final question = _currentQuestion;

    setState(() {
      _answers[question.id] = option.label;
      _selectedOptions[question.id] = option;
    });

    if (_currentStep < _questions.length - 1) {
      setState(() {
        _currentStep++;
      });
      return;
    }

    _finishQuiz();
  }

  Future<void> _finishQuiz() async {
    final result = _calculateResult();
    final scores = _calculateScores();
    final rawDimensions = _calculateRawDimensions();
    final matchDimensions = _normaliseDimensions(rawDimensions);
    final trainerBias = _calculateTrainerBias();
    final matchFlags = _buildMatchFlags(matchDimensions);
    final matchProfile = _buildMatchProfile(
      result: result,
      matchDimensions: matchDimensions,
      rawDimensions: rawDimensions,
      trainerBias: trainerBias,
      matchFlags: matchFlags,
    );

    setState(() {
      _saving = true;
    });

    await _saveResults(
      result: result,
      scores: scores,
      rawDimensions: rawDimensions,
      matchDimensions: matchDimensions,
      trainerBias: trainerBias,
      matchFlags: matchFlags,
      matchProfile: matchProfile,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _QuizResultPage(
          result: result,
          matchProfile: matchProfile,
          matchDimensions: matchDimensions,
        ),
      ),
    );
  }

  Map<String, int> _calculateScores() {
    final scores = {
      for (final key in _badgeResults.keys) key: 0,
    };

    for (final option in _selectedOptions.values) {
      for (final entry in option.scores.entries) {
        scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
      }
    }

    return scores;
  }

  Map<String, int> _calculateRawDimensions() {
    final dimensions = {
      for (final key in _dimensionKeys) key: 0,
    };

    for (final option in _selectedOptions.values) {
      for (final entry in option.dimensions.entries) {
        dimensions[entry.key] = (dimensions[entry.key] ?? 0) + entry.value;
      }
    }

    return dimensions;
  }

  Map<String, int> _normaliseDimensions(Map<String, int> rawDimensions) {
    return {
      for (final key in _dimensionKeys)
        key: _normaliseDimensionValue(rawDimensions[key] ?? 0),
    };
  }

  int _normaliseDimensionValue(int value) {
    if (value <= 0) return 0;
    if (value <= 4) return 1;
    if (value <= 8) return 2;
    if (value <= 12) return 3;
    if (value <= 16) return 4;
    return 5;
  }

  Map<String, int> _calculateTrainerBias() {
    final bias = {
      for (final key in _trainerBiasKeys) key: 0,
    };

    for (final option in _selectedOptions.values) {
      for (final entry in option.trainerBias.entries) {
        bias[entry.key] = (bias[entry.key] ?? 0) + entry.value;
      }
    }

    return bias;
  }

  Map<String, bool> _buildMatchFlags(Map<String, int> matchDimensions) {
    final confidenceNeed = matchDimensions['confidenceNeed'] ?? 0;
    final beginnerSupportNeed = matchDimensions['beginnerSupportNeed'] ?? 0;
    final structureNeed = matchDimensions['structureNeed'] ?? 0;
    final accountabilityNeed = matchDimensions['accountabilityNeed'] ?? 0;
    final intensityTolerance = matchDimensions['intensityTolerance'] ?? 0;
    final communicationWarmthNeed =
        matchDimensions['communicationWarmthNeed'] ?? 0;
    final directnessTolerance = matchDimensions['directnessTolerance'] ?? 0;
    final detailPreference = matchDimensions['detailPreference'] ?? 0;
    final correctionSensitivity = matchDimensions['correctionSensitivity'] ?? 0;
    final technicalCoachingNeed = matchDimensions['technicalCoachingNeed'] ?? 0;
    final aestheticFocus = matchDimensions['aestheticFocus'] ?? 0;
    final strengthFocus = matchDimensions['strengthFocus'] ?? 0;
    final lifestyleFlexibilityNeed =
        matchDimensions['lifestyleFlexibilityNeed'] ?? 0;

    return {
      // These flags are designed for later mismatch prevention.
      'needsWarmCommunication':
          communicationWarmthNeed >= 4 || correctionSensitivity >= 4,
      'avoidHighPressure': intensityTolerance <= 2 || directnessTolerance <= 2,
      'needsBeginnerFriendlyTrainer':
          beginnerSupportNeed >= 4 || confidenceNeed >= 4,
      'needsStructureAndCheckIns':
          structureNeed >= 4 || accountabilityNeed >= 4,
      'needsDetailedTechnicalExplanation':
          technicalCoachingNeed >= 4 || detailPreference >= 4,
      'isAestheticDriven': aestheticFocus >= 4,
      'isStrengthDriven': strengthFocus >= 4,
      'needsLifestyleFlexibility': lifestyleFlexibilityNeed >= 4,
    };
  }

  _BadgeResult _calculateResult() {
    final scores = _calculateScores();

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;

        return _tieBreakerPriority(a.key).compareTo(_tieBreakerPriority(b.key));
      });

    final winningKey = sorted.first.key;
    return _badgeResults[winningKey] ?? _badgeResults['the_momentum']!;
  }

  int _tieBreakerPriority(String key) {
    const priority = {
      'the_comeback': 1,
      'the_momentum': 2,
      'the_strong': 3,
      'the_glow_up': 4,
      'the_balance': 5,
      'the_edge': 6,
    };

    return priority[key] ?? 99;
  }

  Map<String, dynamic> _buildMatchProfile({
    required _BadgeResult result,
    required Map<String, int> matchDimensions,
    required Map<String, int> rawDimensions,
    required Map<String, int> trainerBias,
    required Map<String, bool> matchFlags,
  }) {
    return {
      'experienceStage': _answers['starting_point'] ?? '',
      'primaryGoal': _answers['primary_goal'] ?? '',
      'mainBlocker': _answers['main_blocker'] ?? '',
      'supportNeed': _answers['support_need'] ?? '',
      'correctionStyle': _answers['correction_style'] ?? '',
      'sessionPreference': _answers['session_feel'] ?? '',
      'recommendedTrainerStyleId': result.bestTrainerStyleId,
      'recommendedTrainerStyleName': result.bestTrainerStyleName,
      'secondaryTrainerStyleId': result.secondaryTrainerStyleId,
      'secondaryTrainerStyleName': result.secondaryTrainerStyleName,
      'blindSpotTitle': result.blindSpotTitle,
      'blindSpotDescription': result.blindSpotDescription,
      'matchDimensions': matchDimensions,
      'rawMatchDimensions': rawDimensions,
      'trainerStyleBiasScores': trainerBias,
      'matchFlags': matchFlags,
    };
  }

  Future<void> _saveResults({
    required _BadgeResult result,
    required Map<String, int> scores,
    required Map<String, int> rawDimensions,
    required Map<String, int> matchDimensions,
    required Map<String, int> trainerBias,
    required Map<String, bool> matchFlags,
    required Map<String, dynamic> matchProfile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        // Keep only lightweight top-level fields for quick access elsewhere.
        'fitnessIdentity': result.key,
        'fitnessBadge': result.title,
        'fitnessIdentityUpdatedAt': FieldValue.serverTimestamp(),

        // Main source of truth for the customer identity + matching engine.
        'fitnessIdentityV2': {
          'archetypeId': result.key,
          'archetypeName': result.title,
          'tagline': result.tagline,
          'shortMeaning': result.shortMeaning,
          'trainerMatch': result.trainerMatch,
          'badgeAsset': result.assetPath,
          'quizVersion': 4,
          'answers': _answers,
          'scores': scores,
          'matchProfile': matchProfile,
          'matchDimensions': matchDimensions,
          'rawMatchDimensions': rawDimensions,
          'trainerStyleBiasScores': trainerBias,
          'matchFlags': matchFlags,
          'recommendedTrainerStyles': {
            'primary': {
              'id': result.bestTrainerStyleId,
              'name': result.bestTrainerStyleName,
            },
            'secondary': {
              'id': result.secondaryTrainerStyleId,
              'name': result.secondaryTrainerStyleName,
            },
          },
          'blindSpot': {
            'title': result.blindSpotTitle,
            'description': result.blindSpotDescription,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },

        // Clean up old duplicate fields from previous quiz versions.
        'customerIdentity': FieldValue.delete(),
        'customerBadge': FieldValue.delete(),
        'customerQuizResult': FieldValue.delete(),
        'quizAnswers': FieldValue.delete(),
        'quizScores': FieldValue.delete(),
        'quizResult': FieldValue.delete(),
        'quizCompletedAt': FieldValue.delete(),
        'customerMatchProfile': FieldValue.delete(),
        'customerMatchDimensions': FieldValue.delete(),
        'customerRawMatchDimensions': FieldValue.delete(),
        'customerTrainerStyleBiasScores': FieldValue.delete(),
        'customerMatchFlags': FieldValue.delete(),
        'customerRecommendedTrainerStyleId': FieldValue.delete(),
        'customerRecommendedTrainerStyleName': FieldValue.delete(),
        'customerSecondaryTrainerStyleId': FieldValue.delete(),
        'customerSecondaryTrainerStyleName': FieldValue.delete(),
        'customerBlindSpotTitle': FieldValue.delete(),
        'customerBlindSpotDescription': FieldValue.delete(),
        'customerIdentityScores': FieldValue.delete(),
        'customerQuizVersion': FieldValue.delete(),
        'rawMatchDimensions': FieldValue.delete(),
        'trainerStyleBiasScores': FieldValue.delete(),
        'recommendedTrainerStyles': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  void _goBackOneQuestion() {
    if (_saving) return;

    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  void _restartQuiz() {
    if (_saving) return;

    setState(() {
      _currentStep = 0;
      _answers.clear();
      _selectedOptions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _goBackOneQuestion,
        ),
        title: const Text(
          'Fitness Identity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _restartQuiz,
            child: const Text(
              'Restart',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _QuizHero(
                  progress: _progress,
                  step: _currentStep + 1,
                  totalSteps: _questions.length,
                ),
                const SizedBox(height: 16),
                _QuestionCard(
                  step: _currentStep + 1,
                  totalSteps: _questions.length,
                  question: question,
                  selectedLabel: _answers[question.id],
                  onSelected: _selectOption,
                ),
              ],
            ),
            if (_saving)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: _SavingPanel(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── Page sections ───────────────── */

class _QuizHero extends StatelessWidget {
  final double progress;
  final int step;
  final int totalSteps;

  const _QuizHero({
    required this.progress,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E222B),
            Color(0xFF111318),
            Color(0xFF07080A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -58,
            top: -58,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.13),
              ),
            ),
          ),
          Positioned(
            left: -86,
            bottom: -86,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FAFA3).withValues(alpha: 0.09),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PremiumLabel(text: 'DISCOVER YOUR TYPE'),
                const SizedBox(height: 10),
                const Text(
                  'Find the trainer style that fits you.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Answer 6 quick questions. Fitly will build your identity and hidden match profile.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: _surfaceRaised,
                          color: _gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$step/$totalSteps',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int step;
  final int totalSteps;
  final _QuizQuestion question;
  final String? selectedLabel;
  final ValueChanged<_QuizOption> onSelected;

  const _QuestionCard({
    required this.step,
    required this.totalSteps,
    required this.question,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepPill(text: '$step / $totalSteps'),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            question.subtitle,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            itemCount: question.options.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final option = question.options[index];
              return _OptionTile(
                option: option,
                selected: selectedLabel == option.label,
                onTap: () => onSelected(option),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _QuizOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _gold.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? _gold.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _gold.withValues(alpha: 0.20)),
                  ),
                  child: Icon(option.icon, color: _gold, size: 23),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.2,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavingPanel extends StatelessWidget {
  const _SavingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _gold),
          SizedBox(height: 18),
          Text(
            'Building match profile...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── Compact share image ───────────────── */

Future<Uint8List> _buildCompactShareImageBytes(_BadgeResult result) async {
  const double width = 720;
  const double height = 1280;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  final bgPaint = Paint()
    ..shader = LinearGradient(
      colors: [
        result.accent.withValues(alpha: 0.34),
        _surface,
        _ink,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

  canvas.drawCircle(const Offset(615, 130), 180,
      Paint()..color = result.accent.withValues(alpha: 0.18));
  canvas.drawCircle(
      Offset.zero, 190, Paint()..color = _gold.withValues(alpha: 0.08));
  canvas.drawCircle(const Offset(90, 1160), 210,
      Paint()..color = result.accent.withValues(alpha: 0.08));

  final cardRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(46, 66, 628, 1148),
    const Radius.circular(46),
  );

  canvas.drawRRect(
    cardRect,
    Paint()..color = Colors.black.withValues(alpha: 0.16),
  );
  canvas.drawRRect(
    cardRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = result.accent.withValues(alpha: 0.34),
  );

  _drawCenteredText(
    canvas,
    'FITLY FITNESS IDENTITY',
    y: 128,
    maxWidth: 580,
    style: TextStyle(
      color: result.accent,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.4,
    ),
  );

  final badgeImage = await _loadShareAsset(result.assetPath);
  final badgeRect = Rect.fromCenter(
    center: const Offset(width / 2, 355),
    width: 318,
    height: 318,
  );

  canvas.drawCircle(
    badgeRect.center,
    190,
    Paint()..color = result.accent.withValues(alpha: 0.12),
  );
  canvas.drawCircle(
    badgeRect.center,
    176,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = result.accent.withValues(alpha: 0.22),
  );

  if (badgeImage != null) {
    _drawImageContain(canvas, badgeImage, badgeRect);
  } else {
    _drawCenteredText(
      canvas,
      result.title,
      y: 322,
      maxWidth: 360,
      style: TextStyle(
        color: result.accent,
        fontSize: 42,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  _drawCenteredText(
    canvas,
    result.title,
    y: 570,
    maxWidth: 560,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 58,
      fontWeight: FontWeight.w900,
      height: 1.0,
    ),
  );

  _drawCenteredText(
    canvas,
    result.tagline,
    y: 646,
    maxWidth: 560,
    style: TextStyle(
      color: result.accent,
      fontSize: 31,
      fontWeight: FontWeight.w900,
      height: 1.12,
    ),
  );

  _drawShareInfoBox(
    canvas,
    y: 738,
    title: 'WHAT THIS MEANS',
    body: result.shortMeaning,
    accent: result.accent,
  );

  _drawShareInfoBox(
    canvas,
    y: 900,
    title: 'TRAINER FIT',
    body: result.trainerMatch,
    accent: result.accent,
  );

  _drawCenteredText(
    canvas,
    'Find your trainer style on Fitly',
    y: 1118,
    maxWidth: 560,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.w900,
      height: 1.15,
    ),
  );

  _drawCenteredText(
    canvas,
    'gofitly.com.au',
    y: 1162,
    maxWidth: 560,
    style: TextStyle(
      color: result.accent,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.15,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw Exception('Could not prepare share image.');
  }

  return byteData.buffer.asUint8List();
}

Future<ui.Image?> _loadShareAsset(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

void _drawImageContain(Canvas canvas, ui.Image image, Rect dst) {
  final imageRatio = image.width / image.height;
  final dstRatio = dst.width / dst.height;

  late Rect src;

  if (imageRatio > dstRatio) {
    final srcWidth = image.height * dstRatio;
    final left = (image.width - srcWidth) / 2;
    src = Rect.fromLTWH(left, 0, srcWidth, image.height.toDouble());
  } else {
    final srcHeight = image.width / dstRatio;
    final top = (image.height - srcHeight) / 2;
    src = Rect.fromLTWH(0, top, image.width.toDouble(), srcHeight);
  }

  canvas.drawImageRect(
      image, src, dst, Paint()..filterQuality = FilterQuality.high);
}

void _drawCenteredText(
  Canvas canvas,
  String text, {
  required double y,
  required double maxWidth,
  required TextStyle style,
  int maxLines = 2,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  painter.paint(canvas, Offset((720 - painter.width) / 2, y));
}

void _drawShareInfoBox(
  Canvas canvas, {
  required double y,
  required String title,
  required String body,
  required Color accent,
}) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(90, y, 540, 126),
    const Radius.circular(26),
  );

  canvas.drawRRect(
    rect,
    Paint()..color = Colors.white.withValues(alpha: 0.055),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.24),
  );

  final titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      style: TextStyle(
        color: accent,
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 492);

  titlePainter.paint(canvas, Offset(114, y + 22));

  final bodyPainter = TextPainter(
    text: TextSpan(
      text: body,
      style: const TextStyle(
        color: Color(0xFFE7E9EE),
        fontSize: 23,
        height: 1.22,
        fontWeight: FontWeight.w600,
      ),
    ),
    maxLines: 2,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 492);

  bodyPainter.paint(canvas, Offset(114, y + 58));
}

/* ───────────────── Result page ───────────────── */

class _QuizResultPage extends StatefulWidget {
  final _BadgeResult result;
  final Map<String, dynamic> matchProfile;
  final Map<String, int> matchDimensions;

  const _QuizResultPage({
    required this.result,
    required this.matchProfile,
    required this.matchDimensions,
  });

  @override
  State<_QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<_QuizResultPage> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareResult() async {
    if (_sharing) return;

    setState(() => _sharing = true);

    try {
      final bytes = await _buildCompactShareImageBytes(widget.result);

      await SharePlus.instance.share(
        ShareParams(
          subject: 'My Fitly fitness identity',
          text:
              'I’m ${widget.result.title} on Fitly — ${widget.result.tagline}\nFind your fitness identity on Fitly.',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'fitly_${widget.result.key}.png',
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Share quiz result error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share result. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Your Result',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            RepaintBoundary(
              key: _shareBoundaryKey,
              child: _ResultHero(result: widget.result),
            ),
            const SizedBox(height: 16),
            _ResultInfoCard(
              result: widget.result,
              matchProfile: widget.matchProfile,
              matchDimensions: widget.matchDimensions,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Profile',
                    icon: Icons.person_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: _sharing ? 'Preparing...' : 'Share Result',
                    icon: Icons.ios_share_rounded,
                    onPressed: _sharing ? () {} : _shareResult,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  final _BadgeResult result;

  const _ResultHero({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: result.accent.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            result.accent.withValues(alpha: 0.22),
            _surface,
            _ink,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: result.accent.withValues(alpha: 0.13),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(
          children: [
            const _PremiumLabel(text: 'RESULT UNLOCKED'),
            const SizedBox(height: 18),
            _BadgeImage(result: result, size: 205),
            const SizedBox(height: 20),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: result.accent,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            _FitlyShareFooter(accent: result.accent),
          ],
        ),
      ),
    );
  }
}

class _ResultInfoCard extends StatelessWidget {
  final _BadgeResult result;
  final Map<String, dynamic> matchProfile;
  final Map<String, int> matchDimensions;

  const _ResultInfoCard({
    required this.result,
    required this.matchProfile,
    required this.matchDimensions,
  });

  @override
  Widget build(BuildContext context) {
    final bestTrainer = _trainerStyles[result.bestTrainerStyleId];
    final secondaryTrainer = _trainerStyles[result.secondaryTrainerStyleId];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PremiumLabel(text: 'WHAT THIS MEANS'),
          const SizedBox(height: 12),
          Text(
            result.shortMeaning,
            style: const TextStyle(
              color: Color(0xFFE7E9EE),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _PremiumCallout(
            icon: Icons.visibility_rounded,
            title: 'Blind spot: ${result.blindSpotTitle}',
            subtitle: result.blindSpotDescription,
            accent: result.accent,
          ),
          const SizedBox(height: 12),
          _PremiumCallout(
            icon: Icons.person_search_rounded,
            title:
                'Best trainer style: ${bestTrainer?.name ?? result.bestTrainerStyleName}',
            subtitle: bestTrainer?.description ?? result.trainerMatch,
            accent: result.accent,
          ),
          if (secondaryTrainer != null) ...[
            const SizedBox(height: 12),
            _PremiumCallout(
              icon: Icons.tune_rounded,
              title: 'Secondary fit: ${secondaryTrainer.name}',
              subtitle: secondaryTrainer.description,
              accent: result.accent,
            ),
          ],
          const SizedBox(height: 14),
          const _PremiumLabel(text: 'MATCH SIGNALS'),
          const SizedBox(height: 10),
          _MatchSignalRow(
            label: 'Goal',
            value: matchProfile['primaryGoal']?.toString() ?? '',
          ),
          const SizedBox(height: 8),
          _MatchSignalRow(
            label: 'Support',
            value: matchProfile['supportNeed']?.toString() ?? '',
          ),
          const SizedBox(height: 8),
          _MatchSignalRow(
            label: 'Communication',
            value: matchProfile['correctionStyle']?.toString() ?? '',
          ),
        ],
      ),
    );
  }
}

/* ───────────────── Small reusable widgets ───────────────── */

class _BadgeImage extends StatelessWidget {
  final _BadgeResult result;
  final double size;

  const _BadgeImage({
    required this.result,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: result.accent.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        result.assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Icon(
            result.fallbackIcon,
            color: result.accent,
            size: size * 0.42,
          );
        },
      ),
    );
  }
}

class _FitlyShareFooter extends StatelessWidget {
  final Color accent;

  const _FitlyShareFooter({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: accent,
            size: 16,
          ),
          const SizedBox(width: 7),
          const Flexible(
            child: Text(
              'Find your trainer style on Fitly',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCallout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _PremiumCallout({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchSignalRow extends StatelessWidget {
  final String label;
  final String value;

  const _MatchSignalRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumLabel extends StatelessWidget {
  final String text;

  const _PremiumLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _gold.withValues(alpha: 0.92),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String text;

  const _StepPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _gold,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14.2,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 52),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.black),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
