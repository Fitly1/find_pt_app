// lib/trainer_quiz_page.dart
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

class TrainerQuizPage extends StatefulWidget {
  const TrainerQuizPage({super.key});

  @override
  State<TrainerQuizPage> createState() => _TrainerQuizPageState();
}

/* ───────────────── Result model ───────────────── */

class _TrainerBadgeResult {
  final String key;
  final String title;
  final String tagline;
  final String shortMeaning;
  final String coachingPromise;
  final String idealClient;
  final String assetPath;
  final Color accent;
  final IconData fallbackIcon;

  const _TrainerBadgeResult({
    required this.key,
    required this.title,
    required this.tagline,
    required this.shortMeaning,
    required this.coachingPromise,
    required this.idealClient,
    required this.assetPath,
    required this.accent,
    required this.fallbackIcon,
  });
}

/*
  Final locked trainer identities:
  1. The Guide
  2. The Builder
  3. The Sculptor
  4. The Challenger
  5. The Anchor

  Trainer quiz saves cleanly to:
  trainer_profiles/{uid}.trainerFitnessIdentityV1
*/
const Map<String, _TrainerBadgeResult> _trainerBadgeResults = {
  'the_guide': _TrainerBadgeResult(
    key: 'the_guide',
    title: 'The Guide',
    tagline: 'Start without judgement.',
    shortMeaning:
        'You coach through patience, encouragement, confidence-building, and safe first steps.',
    coachingPromise:
        'You help clients feel comfortable, capable, and supported from the beginning.',
    idealClient:
        'Best for beginners, restart clients, low-confidence clients, and people who need reassurance before intensity.',
    assetPath: 'assets/badges/trainers/the_guide.png',
    accent: Color(0xFFC89A54),
    fallbackIcon: Icons.explore_rounded,
  ),
  'the_builder': _TrainerBadgeResult(
    key: 'the_builder',
    title: 'The Builder',
    tagline: 'Build consistency and capability.',
    shortMeaning:
        'You coach through structure, check-ins, progression, and clear systems clients can repeat.',
    coachingPromise:
        'You help clients turn scattered effort into a plan, routine, and measurable progress.',
    idealClient:
        'Best for inconsistent clients, routine-builders, strength beginners, and people who need accountability.',
    assetPath: 'assets/badges/trainers/the_builder.png',
    accent: Color(0xFF536FA8),
    fallbackIcon: Icons.account_tree_rounded,
  ),
  'the_sculptor': _TrainerBadgeResult(
    key: 'the_sculptor',
    title: 'The Sculptor',
    tagline: 'Shape visible change.',
    shortMeaning:
        'You coach through body composition, physique goals, targeted habits, and visible progress.',
    coachingPromise:
        'You help clients chase body confidence without turning progress into obsession.',
    idealClient:
        'Best for clients focused on fat loss, body shape, photos, clothing confidence, and visible transformation.',
    assetPath: 'assets/badges/trainers/the_sculptor.png',
    accent: Color(0xFFC8B7A0),
    fallbackIcon: Icons.auto_awesome_rounded,
  ),
  'the_challenger': _TrainerBadgeResult(
    key: 'the_challenger',
    title: 'The Challenger',
    tagline: 'Push the next level.',
    shortMeaning:
        'You coach through intensity, direct feedback, high standards, and performance-focused progression.',
    coachingPromise:
        'You help driven clients raise their standard and push harder with purpose.',
    idealClient:
        'Best for competitive, performance-driven, high-intensity clients who respond well to pressure.',
    assetPath: 'assets/badges/trainers/the_challenger.png',
    accent: Color(0xFFB64A42),
    fallbackIcon: Icons.local_fire_department_rounded,
  ),
  'the_anchor': _TrainerBadgeResult(
    key: 'the_anchor',
    title: 'The Anchor',
    tagline: 'Make fitness fit real life.',
    shortMeaning:
        'You coach through calm structure, realistic planning, lifestyle flexibility, and sustainable consistency.',
    coachingPromise:
        'You help clients stay grounded when work, stress, energy, or life gets messy.',
    idealClient:
        'Best for busy, stressed, inconsistent, burned-out, or lifestyle-constrained clients.',
    assetPath: 'assets/badges/trainers/the_anchor.png',
    accent: Color(0xFF4FAFA3),
    fallbackIcon: Icons.anchor_rounded,
  ),
};

const List<String> _trainerDimensionKeys = [
  // Comfort / relationship
  'supportWarmth',
  'beginnerFriendliness',

  // Structure / behaviour change
  'programStructure',
  'accountabilitySystem',
  'communicationFrequency',

  // Intensity / feedback
  'intensityPush',
  'directnessLevel',
  'feedbackSensitivity',

  // Explanation / technical coaching
  'explanationDetail',
  'technicalCoaching',

  // Outcome focus
  'aestheticCoaching',
  'strengthProgression',

  // Lifestyle fit
  'lifestyleAdaptability',
  'autonomySupport',
];

const List<String> _trainerIdentityKeys = [
  'the_guide',
  'the_builder',
  'the_sculptor',
  'the_challenger',
  'the_anchor',
];

const List<String> _customerBiasKeys = [
  'the_comeback',
  'the_momentum',
  'the_strong',
  'the_glow_up',
  'the_edge',
  'the_balance',
];

/* ───────────────── Quiz models ───────────────── */

class _TrainerQuizQuestion {
  final String id;
  final String question;
  final String subtitle;
  final List<_TrainerQuizOption> options;

  const _TrainerQuizQuestion({
    required this.id,
    required this.question,
    required this.subtitle,
    required this.options,
  });
}

class _TrainerQuizOption {
  final String label;
  final String description;
  final IconData icon;
  final Map<String, int> scores;
  final Map<String, int> dimensions;
  final Map<String, int> customerBias;

  const _TrainerQuizOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.scores,
    this.dimensions = const {},
    this.customerBias = const {},
  });
}

const List<_TrainerQuizQuestion> _questions = [
  _TrainerQuizQuestion(
    id: 'core_strength',
    question: 'What are you best at helping clients do?',
    subtitle: 'Choose the coaching outcome that feels most natural to you.',
    options: [
      _TrainerQuizOption(
        label: 'Start with confidence',
        description: 'I help clients feel safe, comfortable, and supported.',
        icon: Icons.volunteer_activism_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'beginnerFriendliness': 5,
          'feedbackSensitivity': 4,
          'intensityPush': 1,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Build routine and structure',
        description: 'I create plans, systems, check-ins, and progression.',
        icon: Icons.account_tree_rounded,
        scores: {'the_builder': 5, 'the_guide': 1},
        dimensions: {
          'programStructure': 5,
          'accountabilitySystem': 5,
          'communicationFrequency': 4,
          'explanationDetail': 3,
        },
        customerBias: {'the_momentum': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Shape visible change',
        description: 'I coach body composition, physique, and confidence.',
        icon: Icons.auto_awesome_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'programStructure': 3,
          'accountabilitySystem': 3,
          'explanationDetail': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Push the next level',
        description: 'I raise standards and challenge clients to perform.',
        icon: Icons.local_fire_department_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'intensityPush': 5,
          'directnessLevel': 5,
          'strengthProgression': 4,
          'accountabilitySystem': 3,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Make fitness fit real life',
        description: 'I adapt training around stress, time, and routine.',
        icon: Icons.anchor_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'supportWarmth': 3,
          'intensityPush': 1,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'best_client',
    question: 'Who do you work best with?',
    subtitle: 'This helps Fitly avoid poor client-trainer fit.',
    options: [
      _TrainerQuizOption(
        label: 'Nervous or new clients',
        description:
            'They need patience, encouragement, and clear first steps.',
        icon: Icons.handshake_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'beginnerFriendliness': 5,
          'feedbackSensitivity': 4,
          'technicalCoaching': 2,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Inconsistent clients',
        description: 'They need routine, check-ins, and a clear system.',
        icon: Icons.trending_up_rounded,
        scores: {'the_builder': 5, 'the_guide': 1},
        dimensions: {
          'programStructure': 5,
          'accountabilitySystem': 5,
          'communicationFrequency': 4,
          'supportWarmth': 2,
        },
        customerBias: {'the_momentum': 5, 'the_comeback': 2},
      ),
      _TrainerQuizOption(
        label: 'Body transformation clients',
        description: 'They want visible change and honest progress guidance.',
        icon: Icons.visibility_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'accountabilitySystem': 4,
          'programStructure': 3,
          'feedbackSensitivity': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Driven clients',
        description: 'They like pressure, standards, and direct feedback.',
        icon: Icons.bolt_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'intensityPush': 5,
          'directnessLevel': 5,
          'strengthProgression': 4,
          'programStructure': 2,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Busy lifestyle clients',
        description: 'They need realistic plans that survive messy weeks.',
        icon: Icons.event_available_rounded,
        scores: {'the_anchor': 5, 'the_builder': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'programStructure': 2,
          'supportWarmth': 3,
        },
        customerBias: {'the_balance': 5, 'the_momentum': 1},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'falling_off_response',
    question: 'When a client starts falling off, what do you do first?',
    subtitle: 'This reveals your real accountability style.',
    options: [
      _TrainerQuizOption(
        label: 'Rebuild confidence',
        description: 'I reduce overwhelm and help them restart without shame.',
        icon: Icons.favorite_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'beginnerFriendliness': 4,
          'feedbackSensitivity': 5,
          'intensityPush': 1,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Reset the structure',
        description: 'I tighten the plan, check-ins, and weekly targets.',
        icon: Icons.route_rounded,
        scores: {'the_builder': 5, 'the_challenger': 1},
        dimensions: {
          'programStructure': 5,
          'accountabilitySystem': 5,
          'communicationFrequency': 4,
          'directnessLevel': 3,
        },
        customerBias: {'the_momentum': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Refocus on visible milestones',
        description: 'I reconnect them to habits, measurements, and progress.',
        icon: Icons.insights_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'accountabilitySystem': 4,
          'feedbackSensitivity': 3,
          'programStructure': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Challenge the pattern',
        description: 'I call it out directly and raise the standard.',
        icon: Icons.campaign_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'directnessLevel': 5,
          'intensityPush': 5,
          'accountabilitySystem': 4,
          'feedbackSensitivity': 1,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Adjust around life',
        description: 'I modify the plan so they can keep going realistically.',
        icon: Icons.self_improvement_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'supportWarmth': 3,
          'programStructure': 2,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'feedback_style',
    question: 'How do you usually give feedback?',
    subtitle: 'Communication style is a major comfort signal for clients.',
    options: [
      _TrainerQuizOption(
        label: 'Warm and encouraging',
        description: 'I correct clients without making them feel judged.',
        icon: Icons.favorite_border_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'feedbackSensitivity': 5,
          'beginnerFriendliness': 3,
          'directnessLevel': 1,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Clear and step-by-step',
        description: 'I explain what to change and why it matters.',
        icon: Icons.format_list_numbered_rounded,
        scores: {'the_builder': 5, 'the_guide': 1},
        dimensions: {
          'explanationDetail': 5,
          'technicalCoaching': 4,
          'programStructure': 3,
          'supportWarmth': 2,
        },
        customerBias: {'the_momentum': 4, 'the_strong': 4},
      ),
      _TrainerQuizOption(
        label: 'Honest about progress',
        description: 'I keep it supportive but realistic about body change.',
        icon: Icons.auto_graph_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'feedbackSensitivity': 3,
          'explanationDetail': 3,
          'accountabilitySystem': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Direct and no-nonsense',
        description: 'I say what needs to be said and push standards.',
        icon: Icons.record_voice_over_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'directnessLevel': 5,
          'intensityPush': 4,
          'accountabilitySystem': 4,
          'feedbackSensitivity': 1,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Calm and flexible',
        description: 'I adjust tone and pressure based on the client’s week.',
        icon: Icons.tune_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 4,
          'autonomySupport': 4,
          'supportWarmth': 3,
          'feedbackSensitivity': 4,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'program_style',
    question: 'How do you structure training?',
    subtitle:
        'This helps Fitly match your delivery style, not just your goal type.',
    options: [
      _TrainerQuizOption(
        label: 'Gentle progression',
        description: 'Small wins first, then gradual confidence and ability.',
        icon: Icons.stacked_line_chart_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'beginnerFriendliness': 5,
          'supportWarmth': 4,
          'technicalCoaching': 3,
          'intensityPush': 1,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Planned blocks and tracking',
        description:
            'Structured programming, measurable goals, and progression.',
        icon: Icons.view_timeline_rounded,
        scores: {'the_builder': 5, 'the_challenger': 1},
        dimensions: {
          'programStructure': 5,
          'strengthProgression': 4,
          'accountabilitySystem': 4,
          'explanationDetail': 3,
        },
        customerBias: {'the_momentum': 5, 'the_strong': 4},
      ),
      _TrainerQuizOption(
        label: 'Targeted body composition',
        description:
            'Training and habits shaped around visible transformation.',
        icon: Icons.diamond_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'programStructure': 4,
          'accountabilitySystem': 3,
          'technicalCoaching': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'High standards and intensity',
        description:
            'Hard sessions, direct standards, and performance pressure.',
        icon: Icons.flash_on_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'intensityPush': 5,
          'directnessLevel': 4,
          'strengthProgression': 4,
          'programStructure': 3,
        },
        customerBias: {'the_edge': 5, 'the_strong': 3},
      ),
      _TrainerQuizOption(
        label: 'Flexible lifestyle plans',
        description: 'Training that adapts around stress, time, and energy.',
        icon: Icons.calendar_month_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'programStructure': 2,
          'supportWarmth': 3,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'accountability_style',
    question: 'What is your accountability style?',
    subtitle:
        'Different clients respond to very different levels of follow-up.',
    options: [
      _TrainerQuizOption(
        label: 'Supportive reminders',
        description:
            'I keep clients encouraged without making them feel pressured.',
        icon: Icons.notifications_active_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'communicationFrequency': 3,
          'feedbackSensitivity': 4,
          'accountabilitySystem': 2,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Regular check-ins',
        description: 'I track habits, attendance, effort, and weekly progress.',
        icon: Icons.verified_user_rounded,
        scores: {'the_builder': 5, 'the_sculptor': 1},
        dimensions: {
          'accountabilitySystem': 5,
          'communicationFrequency': 5,
          'programStructure': 4,
          'explanationDetail': 2,
        },
        customerBias: {'the_momentum': 5, 'the_glow_up': 2},
      ),
      _TrainerQuizOption(
        label: 'Progress tracking',
        description:
            'I use photos, measurements, habits, or body-composition cues.',
        icon: Icons.query_stats_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'accountabilitySystem': 5,
          'communicationFrequency': 4,
          'feedbackSensitivity': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Firm follow-up',
        description: 'I challenge missed effort and keep the standard high.',
        icon: Icons.gavel_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'directnessLevel': 5,
          'intensityPush': 4,
          'accountabilitySystem': 5,
          'communicationFrequency': 3,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Flexible check-ins',
        description:
            'I keep people accountable without ignoring their real life.',
        icon: Icons.event_repeat_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 4,
          'communicationFrequency': 3,
          'supportWarmth': 3,
        },
        customerBias: {'the_balance': 5, 'the_momentum': 1},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'session_feel',
    question: 'What should your sessions feel like?',
    subtitle: 'This becomes a key matching signal on trainer cards later.',
    options: [
      _TrainerQuizOption(
        label: 'Safe and confidence-building',
        description: 'Clients should leave feeling capable, not embarrassed.',
        icon: Icons.shield_rounded,
        scores: {'the_guide': 5, 'the_anchor': 1},
        dimensions: {
          'supportWarmth': 5,
          'beginnerFriendliness': 5,
          'feedbackSensitivity': 4,
          'intensityPush': 1,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Structured and repeatable',
        description: 'Clients should know what they are doing and why.',
        icon: Icons.repeat_rounded,
        scores: {'the_builder': 5, 'the_guide': 1},
        dimensions: {
          'programStructure': 5,
          'explanationDetail': 4,
          'technicalCoaching': 3,
          'accountabilitySystem': 3,
        },
        customerBias: {'the_momentum': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Targeted and body-focused',
        description:
            'Clients should feel each session connects to visible change.',
        icon: Icons.auto_graph_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'technicalCoaching': 3,
          'programStructure': 3,
          'explanationDetail': 3,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Hard and standards-driven',
        description: 'Clients should feel challenged and pushed to level up.',
        icon: Icons.whatshot_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'intensityPush': 5,
          'directnessLevel': 4,
          'strengthProgression': 4,
          'accountabilitySystem': 3,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Realistic and sustainable',
        description: 'Clients should feel progress can fit their actual life.',
        icon: Icons.spa_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'supportWarmth': 3,
          'intensityPush': 1,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
  _TrainerQuizQuestion(
    id: 'flexibility',
    question: 'How do you handle messy weeks?',
    subtitle: 'This separates rigid coaching from adaptive coaching.',
    options: [
      _TrainerQuizOption(
        label: 'Reassure and restart',
        description: 'I help the client restart without shame or panic.',
        icon: Icons.restart_alt_rounded,
        scores: {'the_guide': 5, 'the_anchor': 2},
        dimensions: {
          'supportWarmth': 5,
          'feedbackSensitivity': 5,
          'beginnerFriendliness': 3,
          'lifestyleAdaptability': 3,
        },
        customerBias: {'the_comeback': 5, 'the_balance': 2},
      ),
      _TrainerQuizOption(
        label: 'Adjust but keep structure',
        description:
            'I change the plan, but keep the routine and check-ins alive.',
        icon: Icons.tune_rounded,
        scores: {'the_builder': 4, 'the_anchor': 3},
        dimensions: {
          'programStructure': 4,
          'accountabilitySystem': 4,
          'lifestyleAdaptability': 4,
          'communicationFrequency': 3,
        },
        customerBias: {'the_momentum': 5, 'the_balance': 3},
      ),
      _TrainerQuizOption(
        label: 'Protect transformation goals',
        description: 'I adjust targets while keeping visible progress moving.',
        icon: Icons.track_changes_rounded,
        scores: {'the_sculptor': 5, 'the_builder': 1},
        dimensions: {
          'aestheticCoaching': 5,
          'programStructure': 3,
          'accountabilitySystem': 4,
          'lifestyleAdaptability': 2,
        },
        customerBias: {'the_glow_up': 5, 'the_momentum': 2},
      ),
      _TrainerQuizOption(
        label: 'Reset the standard',
        description: 'I expect commitment and challenge the client to refocus.',
        icon: Icons.flag_rounded,
        scores: {'the_challenger': 5, 'the_builder': 1},
        dimensions: {
          'directnessLevel': 5,
          'intensityPush': 4,
          'accountabilitySystem': 4,
          'lifestyleAdaptability': 1,
        },
        customerBias: {'the_edge': 5, 'the_strong': 2},
      ),
      _TrainerQuizOption(
        label: 'Adapt heavily around life',
        description:
            'I reduce friction so they can stay consistent realistically.',
        icon: Icons.anchor_rounded,
        scores: {'the_anchor': 5, 'the_guide': 1},
        dimensions: {
          'lifestyleAdaptability': 5,
          'autonomySupport': 5,
          'supportWarmth': 3,
          'feedbackSensitivity': 3,
        },
        customerBias: {'the_balance': 5, 'the_comeback': 2},
      ),
    ],
  ),
];

class _TrainerQuizPageState extends State<TrainerQuizPage> {
  int _currentStep = 0;
  bool _saving = false;

  final Map<String, String> _answers = {};
  final Map<String, _TrainerQuizOption> _selectedOptions = {};

  double get _progress => (_currentStep + 1) / _questions.length;
  _TrainerQuizQuestion get _currentQuestion => _questions[_currentStep];

  void _selectOption(_TrainerQuizOption option) {
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
    final customerBias = _calculateCustomerBias();
    final matchFlags = _buildTrainerMatchFlags(matchDimensions);
    final matchProfile = _buildTrainerMatchProfile(
      result: result,
      matchDimensions: matchDimensions,
      rawDimensions: rawDimensions,
      customerBias: customerBias,
      matchFlags: matchFlags,
    );

    setState(() => _saving = true);

    await _saveResults(
      result: result,
      scores: scores,
      rawDimensions: rawDimensions,
      matchDimensions: matchDimensions,
      customerBias: customerBias,
      matchFlags: matchFlags,
      matchProfile: matchProfile,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    // Replace the quiz route with the result route.
    // This prevents the Profile button from returning to the quiz screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _TrainerQuizResultPage(
          result: result,
          matchProfile: matchProfile,
        ),
      ),
    );
  }

  Map<String, int> _calculateScores() {
    final scores = {
      for (final key in _trainerIdentityKeys) key: 0,
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
      for (final key in _trainerDimensionKeys) key: 0,
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
      for (final key in _trainerDimensionKeys)
        key: _normaliseDimensionValue(rawDimensions[key] ?? 0),
    };
  }

  int _normaliseDimensionValue(int value) {
    if (value <= 0) return 0;
    if (value <= 5) return 1;
    if (value <= 10) return 2;
    if (value <= 15) return 3;
    if (value <= 20) return 4;
    return 5;
  }

  Map<String, int> _calculateCustomerBias() {
    final bias = {
      for (final key in _customerBiasKeys) key: 0,
    };

    for (final option in _selectedOptions.values) {
      for (final entry in option.customerBias.entries) {
        bias[entry.key] = (bias[entry.key] ?? 0) + entry.value;
      }
    }

    return bias;
  }

  Map<String, bool> _buildTrainerMatchFlags(Map<String, int> dimensions) {
    final supportWarmth = dimensions['supportWarmth'] ?? 0;
    final beginnerFriendliness = dimensions['beginnerFriendliness'] ?? 0;
    final programStructure = dimensions['programStructure'] ?? 0;
    final accountabilitySystem = dimensions['accountabilitySystem'] ?? 0;
    final communicationFrequency = dimensions['communicationFrequency'] ?? 0;
    final intensityPush = dimensions['intensityPush'] ?? 0;
    final directnessLevel = dimensions['directnessLevel'] ?? 0;
    final feedbackSensitivity = dimensions['feedbackSensitivity'] ?? 0;
    final explanationDetail = dimensions['explanationDetail'] ?? 0;
    final technicalCoaching = dimensions['technicalCoaching'] ?? 0;
    final aestheticCoaching = dimensions['aestheticCoaching'] ?? 0;
    final strengthProgression = dimensions['strengthProgression'] ?? 0;
    final lifestyleAdaptability = dimensions['lifestyleAdaptability'] ?? 0;
    final autonomySupport = dimensions['autonomySupport'] ?? 0;

    return {
      'warmSupportCoach': supportWarmth >= 4 || feedbackSensitivity >= 4,
      'beginnerFriendlyCoach': beginnerFriendliness >= 4,
      'strongStructureCoach':
          programStructure >= 4 || accountabilitySystem >= 4,
      'frequentCheckInCoach': communicationFrequency >= 4,
      'highIntensityCoach': intensityPush >= 4,
      'directFeedbackCoach': directnessLevel >= 4,
      'detailedExplanationCoach':
          explanationDetail >= 4 || technicalCoaching >= 4,
      'aestheticCoach': aestheticCoaching >= 4,
      'strengthProgressionCoach': strengthProgression >= 4,
      'lifestyleFlexibleCoach':
          lifestyleAdaptability >= 4 || autonomySupport >= 4,
    };
  }

  _TrainerBadgeResult _calculateResult() {
    final scores = _calculateScores();

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;

        return _tieBreakerPriority(a.key).compareTo(_tieBreakerPriority(b.key));
      });

    final winningKey = sorted.first.key;
    return _trainerBadgeResults[winningKey] ??
        _trainerBadgeResults['the_builder']!;
  }

  int _tieBreakerPriority(String key) {
    const priority = {
      'the_guide': 1,
      'the_builder': 2,
      'the_anchor': 3,
      'the_sculptor': 4,
      'the_challenger': 5,
    };

    return priority[key] ?? 99;
  }

  Map<String, dynamic> _buildTrainerMatchProfile({
    required _TrainerBadgeResult result,
    required Map<String, int> matchDimensions,
    required Map<String, int> rawDimensions,
    required Map<String, int> customerBias,
    required Map<String, bool> matchFlags,
  }) {
    return {
      'coreStrength': _answers['core_strength'] ?? '',
      'bestClient': _answers['best_client'] ?? '',
      'fallingOffResponse': _answers['falling_off_response'] ?? '',
      'feedbackStyle': _answers['feedback_style'] ?? '',
      'programStyle': _answers['program_style'] ?? '',
      'accountabilityStyle': _answers['accountability_style'] ?? '',
      'sessionFeel': _answers['session_feel'] ?? '',
      'flexibility': _answers['flexibility'] ?? '',
      'trainerStyleId': result.key,
      'trainerStyleName': result.title,
      'coachingPromise': result.coachingPromise,
      'idealClient': result.idealClient,
      'matchDimensions': matchDimensions,
      'rawMatchDimensions': rawDimensions,
      'idealCustomerBiasScores': customerBias,
      'matchFlags': matchFlags,
    };
  }

  Future<void> _saveResults({
    required _TrainerBadgeResult result,
    required Map<String, int> scores,
    required Map<String, int> rawDimensions,
    required Map<String, int> matchDimensions,
    required Map<String, int> customerBias,
    required Map<String, bool> matchFlags,
    required Map<String, dynamic> matchProfile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(user.uid)
        .set(
      {
        // Top-level quick access fields.
        'trainerIdentity': result.key,
        'trainerBadge': result.title,
        'trainerFitnessIdentityUpdatedAt': FieldValue.serverTimestamp(),

        // Main source of truth for trainer matching.
        'trainerFitnessIdentityV1': {
          'archetypeId': result.key,
          'archetypeName': result.title,
          'tagline': result.tagline,
          'shortMeaning': result.shortMeaning,
          'coachingPromise': result.coachingPromise,
          'idealClient': result.idealClient,
          'badgeAsset': result.assetPath,
          'quizVersion': 1,
          'answers': _answers,
          'scores': scores,
          'matchProfile': matchProfile,
          'matchDimensions': matchDimensions,
          'rawMatchDimensions': rawDimensions,
          'idealCustomerBiasScores': customerBias,
          'matchFlags': matchFlags,
          'updatedAt': FieldValue.serverTimestamp(),
        },
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
          'Coaching Identity',
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
                child: const Center(child: _SavingPanel()),
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
                color: const Color(0xFF536FA8).withValues(alpha: 0.09),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PremiumLabel(text: 'TRAINER COACHING TYPE'),
                const SizedBox(height: 10),
                const Text(
                  'Find your coaching identity.',
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
                  'Answer 8 questions so Fitly can match you with the clients most likely to fit your coaching style.',
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
  final _TrainerQuizQuestion question;
  final String? selectedLabel;
  final ValueChanged<_TrainerQuizOption> onSelected;

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
              fontSize: 23,
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
          ...question.options.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionCard(
                option: option,
                selected: selectedLabel == option.label,
                onTap: () => onSelected(option),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final _TrainerQuizOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
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
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        maxLines: 3,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 12.4,
                          height: 1.28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color:
                      selected ? _gold : Colors.white.withValues(alpha: 0.22),
                  size: 20,
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
      width: 245,
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
            'Building coaching profile...',
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

Future<Uint8List> _buildCompactShareImageBytes(
    _TrainerBadgeResult result) async {
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
    'FITLY COACHING IDENTITY',
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
    title: 'COACHING STYLE',
    body: result.shortMeaning,
    accent: result.accent,
  );

  _drawShareInfoBox(
    canvas,
    y: 900,
    title: 'BEST-FIT CLIENTS',
    body: result.idealClient,
    accent: result.accent,
  );

  _drawCenteredText(
    canvas,
    'Find your coaching identity on Fitly',
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

class _TrainerQuizResultPage extends StatefulWidget {
  final _TrainerBadgeResult result;
  final Map<String, dynamic> matchProfile;

  const _TrainerQuizResultPage({
    required this.result,
    required this.matchProfile,
  });

  @override
  State<_TrainerQuizResultPage> createState() => _TrainerQuizResultPageState();
}

class _TrainerQuizResultPageState extends State<_TrainerQuizResultPage> {
  bool _sharing = false;

  Future<void> _shareResult() async {
    if (_sharing) return;

    setState(() => _sharing = true);

    try {
      final bytes = await _buildCompactShareImageBytes(widget.result);

      await SharePlus.instance.share(
        ShareParams(
          subject: 'My Fitly coaching identity',
          text:
              'I’m ${widget.result.title} on Fitly — ${widget.result.tagline}\nFind your coaching identity on Fitly.',
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
      debugPrint('Share trainer quiz result error: $e');

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
          'Your Coaching Identity',
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
            _ResultHero(result: widget.result),
            const SizedBox(height: 16),
            _ResultInfoCard(
              result: widget.result,
              matchProfile: widget.matchProfile,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Profile',
                    icon: Icons.person_rounded,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: _sharing ? 'Preparing...' : 'Share',
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
  final _TrainerBadgeResult result;

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
            const _PremiumLabel(text: 'COACHING IDENTITY UNLOCKED'),
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
            _FitlyFooter(accent: result.accent),
          ],
        ),
      ),
    );
  }
}

class _ResultInfoCard extends StatelessWidget {
  final _TrainerBadgeResult result;
  final Map<String, dynamic> matchProfile;

  const _ResultInfoCard({
    required this.result,
    required this.matchProfile,
  });

  @override
  Widget build(BuildContext context) {
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
            icon: Icons.verified_rounded,
            title: 'Coaching promise',
            subtitle: result.coachingPromise,
            accent: result.accent,
          ),
          const SizedBox(height: 12),
          _PremiumCallout(
            icon: Icons.people_alt_rounded,
            title: 'Best-fit clients',
            subtitle: result.idealClient,
            accent: result.accent,
          ),
          const SizedBox(height: 14),
          const _PremiumLabel(text: 'COACHING SIGNALS'),
          const SizedBox(height: 10),
          _SignalRow(
            label: 'Strength',
            value: matchProfile['coreStrength']?.toString() ?? '',
          ),
          const SizedBox(height: 8),
          _SignalRow(
            label: 'Client',
            value: matchProfile['bestClient']?.toString() ?? '',
          ),
          const SizedBox(height: 8),
          _SignalRow(
            label: 'Feedback',
            value: matchProfile['feedbackStyle']?.toString() ?? '',
          ),
        ],
      ),
    );
  }
}

/* ───────────────── Small widgets ───────────────── */

class _BadgeImage extends StatelessWidget {
  final _TrainerBadgeResult result;
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

class _FitlyFooter extends StatelessWidget {
  final Color accent;

  const _FitlyFooter({required this.accent});

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
              'Find your coaching identity on Fitly',
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

class _SignalRow extends StatelessWidget {
  final String label;
  final String value;

  const _SignalRow({
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
          width: 74,
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
