// lib/widgets/trainer_fitness_identity_card.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../trainer_quiz_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceAlt = Color(0xFF171B22);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _text = Color(0xFFF5F6F8);

class TrainerFitnessIdentityCard extends StatefulWidget {
  const TrainerFitnessIdentityCard({super.key});

  @override
  State<TrainerFitnessIdentityCard> createState() =>
      _TrainerFitnessIdentityCardState();
}

class _TrainerFitnessIdentityCardState
    extends State<TrainerFitnessIdentityCard> {
  bool _sharing = false;

  Future<void> _openQuiz() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainerQuizPage()),
    );
  }

  Future<void> _shareIdentity(_TrainerIdentityDisplay identity) async {
    if (_sharing) return;

    setState(() => _sharing = true);

    try {
      final bytes = await _buildCompactShareImageBytes(identity);

      await SharePlus.instance.share(
        ShareParams(
          subject: 'My Fitly coaching identity',
          text:
              'I’m ${identity.title} on Fitly — ${identity.tagline}\nFind your coaching identity on Fitly.',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'fitly_${identity.key}.png',
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Share trainer identity error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share badge. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _TrainerIdentityPromptCard(onPressed: _openQuiz);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _TrainerIdentityLoadingCard();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final identityData = data['trainerFitnessIdentityV1'];

        final identity = _identityFromData(identityData);

        if (identity == null) {
          return _TrainerIdentityPromptCard(onPressed: _openQuiz);
        }

        return _TrainerIdentityUnlockedCard(
          identity: identity,
          sharing: _sharing,
          onRetake: _openQuiz,
          onShare: () => _shareIdentity(identity),
        );
      },
    );
  }

  _TrainerIdentityDisplay? _identityFromData(dynamic identityData) {
    if (identityData is! Map) return null;

    final data = Map<String, dynamic>.from(identityData);

    final key = _normaliseTrainerKey(
      data['archetypeId'] ?? data['key'] ?? data['trainerIdentity'],
    );

    if (key.isEmpty) return null;

    return _trainerIdentityLibrary[key]?.copyWith(
          title: _asString(data['archetypeName'] ?? data['title']),
          tagline: _asString(data['tagline']),
          shortMeaning: _asString(data['shortMeaning']),
          coachingPromise: _asString(data['coachingPromise']),
          idealClient: _asString(data['idealClient']),
          assetPath: _asString(data['badgeAsset'] ?? data['assetPath']),
        ) ??
        _TrainerIdentityDisplay(
          key: key,
          title: _titleFromKey(key),
          tagline: 'Your coaching identity.',
          shortMeaning:
              'Your badge helps Fitly match you with clients who fit your coaching style.',
          coachingPromise:
              'Your coaching style helps clients understand what working with you feels like.',
          idealClient:
              'Best-fit client details will appear after completing the trainer quiz.',
          assetPath: 'assets/badges/trainers/$key.png',
          accent: _gold,
          fallbackIcon: Icons.workspace_premium_rounded,
        );
  }

  String _asString(dynamic value) => value?.toString().trim() ?? '';

  String _normaliseTrainerKey(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';

    if (raw.isEmpty) return '';

    final cleaned = raw
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (cleaned.startsWith('the_')) return cleaned;

    return 'the_$cleaned';
  }

  String _titleFromKey(String key) {
    final words = key
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return words.isEmpty ? 'Coaching Identity' : words;
  }
}

/* ───────────────── Identity model/library ───────────────── */

class _TrainerIdentityDisplay {
  final String key;
  final String title;
  final String tagline;
  final String shortMeaning;
  final String coachingPromise;
  final String idealClient;
  final String assetPath;
  final Color accent;
  final IconData fallbackIcon;

  const _TrainerIdentityDisplay({
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

  _TrainerIdentityDisplay copyWith({
    String? title,
    String? tagline,
    String? shortMeaning,
    String? coachingPromise,
    String? idealClient,
    String? assetPath,
  }) {
    return _TrainerIdentityDisplay(
      key: key,
      title: title != null && title.isNotEmpty ? title : this.title,
      tagline: tagline != null && tagline.isNotEmpty ? tagline : this.tagline,
      shortMeaning: shortMeaning != null && shortMeaning.isNotEmpty
          ? shortMeaning
          : this.shortMeaning,
      coachingPromise: coachingPromise != null && coachingPromise.isNotEmpty
          ? coachingPromise
          : this.coachingPromise,
      idealClient: idealClient != null && idealClient.isNotEmpty
          ? idealClient
          : this.idealClient,
      assetPath: assetPath != null && assetPath.isNotEmpty
          ? assetPath
          : this.assetPath,
      accent: accent,
      fallbackIcon: fallbackIcon,
    );
  }
}

const Map<String, _TrainerIdentityDisplay> _trainerIdentityLibrary = {
  'the_guide': _TrainerIdentityDisplay(
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
  'the_builder': _TrainerIdentityDisplay(
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
  'the_sculptor': _TrainerIdentityDisplay(
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
  'the_challenger': _TrainerIdentityDisplay(
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
  'the_anchor': _TrainerIdentityDisplay(
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

/* ───────────────── Main cards ───────────────── */

class _TrainerIdentityUnlockedCard extends StatelessWidget {
  final _TrainerIdentityDisplay identity;
  final bool sharing;
  final VoidCallback onRetake;
  final VoidCallback onShare;

  const _TrainerIdentityUnlockedCard({
    required this.identity,
    required this.sharing,
    required this.onRetake,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: identity.accent.withValues(alpha: 0.38)),
        gradient: LinearGradient(
          colors: [
            identity.accent.withValues(alpha: 0.20),
            _surfaceAlt,
            _ink,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: identity.accent.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: identity.accent.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            left: -95,
            bottom: -95,
            child: Container(
              width: 215,
              height: 215,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _PremiumLabel(
                    text: 'COACHING IDENTITY',
                    color: identity.accent,
                  ),
                ),
                const SizedBox(height: 14),
                _BadgeShowcase(identity: identity),
                const SizedBox(height: 16),
                Text(
                  identity.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 32,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.75,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  identity.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: identity.accent,
                    fontSize: 15.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _MeaningBox(
                  title: 'What this means',
                  text: identity.shortMeaning,
                  accent: identity.accent,
                ),
                const SizedBox(height: 10),
                _MeaningBox(
                  title: 'Coaching promise',
                  text: identity.coachingPromise,
                  accent: identity.accent,
                ),
                const SizedBox(height: 10),
                _MeaningBox(
                  title: 'Best-fit clients',
                  text: identity.idealClient,
                  accent: identity.accent,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Retake',
                        icon: Icons.refresh_rounded,
                        onPressed: onRetake,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryButton(
                        label: sharing ? 'Preparing...' : 'Share Badge',
                        icon: Icons.ios_share_rounded,
                        onPressed: sharing ? () {} : onShare,
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

class _TrainerIdentityPromptCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _TrainerIdentityPromptCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _gold.withValues(alpha: 0.32)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _gold,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trainer Identity',
                    style: TextStyle(
                      color: _text,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Discover your coaching style and badge.',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onPressed,
              child: const Text(
                'Discover',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerIdentityLoadingCard extends StatelessWidget {
  const _TrainerIdentityLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: _gold,
            strokeWidth: 2.2,
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Display widgets ───────────────── */

class _BadgeShowcase extends StatelessWidget {
  final _TrainerIdentityDisplay identity;

  const _BadgeShowcase({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 212,
      height: 212,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            identity.accent.withValues(alpha: 0.23),
            Colors.black.withValues(alpha: 0.20),
            Colors.black.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: identity.accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: identity.accent.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Image.asset(
        identity.assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(
              identity.fallbackIcon,
              color: identity.accent,
              size: 82,
            ),
          );
        },
      ),
    );
  }
}

class _MeaningBox extends StatelessWidget {
  final String title;
  final String text;
  final Color accent;

  const _MeaningBox({
    required this.title,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE7E9EE),
              fontSize: 13.7,
              height: 1.34,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _PremiumLabel({
    required this.text,
    this.color = _gold,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.92),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
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
          fontSize: 13.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
          fontSize: 13.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/* ───────────────── Compact share image ───────────────── */

Future<Uint8List> _buildCompactShareImageBytes(
    _TrainerIdentityDisplay identity) async {
  const double width = 720;
  const double height = 1280;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  final bgPaint = Paint()
    ..shader = LinearGradient(
      colors: [
        identity.accent.withValues(alpha: 0.34),
        _surface,
        _ink,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

  canvas.drawCircle(const Offset(615, 130), 180,
      Paint()..color = identity.accent.withValues(alpha: 0.18));
  canvas.drawCircle(
      Offset.zero, 190, Paint()..color = _gold.withValues(alpha: 0.08));
  canvas.drawCircle(const Offset(90, 1160), 210,
      Paint()..color = identity.accent.withValues(alpha: 0.08));

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
      ..color = identity.accent.withValues(alpha: 0.34),
  );

  _drawCenteredText(
    canvas,
    'FITLY COACHING IDENTITY',
    y: 128,
    maxWidth: 580,
    style: TextStyle(
      color: identity.accent,
      fontSize: 24,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.4,
    ),
  );

  final badgeImage = await _loadShareAsset(identity.assetPath);
  final badgeRect = Rect.fromCenter(
    center: const Offset(width / 2, 355),
    width: 318,
    height: 318,
  );

  canvas.drawCircle(
    badgeRect.center,
    190,
    Paint()..color = identity.accent.withValues(alpha: 0.12),
  );
  canvas.drawCircle(
    badgeRect.center,
    176,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = identity.accent.withValues(alpha: 0.22),
  );

  if (badgeImage != null) {
    _drawImageContain(canvas, badgeImage, badgeRect);
  } else {
    _drawCenteredText(
      canvas,
      identity.title,
      y: 322,
      maxWidth: 360,
      style: TextStyle(
        color: identity.accent,
        fontSize: 42,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  _drawCenteredText(
    canvas,
    identity.title,
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
    identity.tagline,
    y: 646,
    maxWidth: 560,
    style: TextStyle(
      color: identity.accent,
      fontSize: 31,
      fontWeight: FontWeight.w900,
      height: 1.12,
    ),
  );

  _drawShareInfoBox(
    canvas,
    y: 738,
    title: 'COACHING STYLE',
    body: identity.shortMeaning,
    accent: identity.accent,
  );

  _drawShareInfoBox(
    canvas,
    y: 900,
    title: 'BEST-FIT CLIENTS',
    body: identity.idealClient,
    accent: identity.accent,
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
      color: identity.accent,
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
