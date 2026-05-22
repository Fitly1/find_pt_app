// lib/widgets/customer_fitness_identity_card.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../customer_quiz_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _brandColor = Color(0xFFFFA726);
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);

class CustomerFitnessIdentityCard extends StatefulWidget {
  const CustomerFitnessIdentityCard({super.key});

  @override
  State<CustomerFitnessIdentityCard> createState() =>
      _CustomerFitnessIdentityCardState();
}

class _CustomerFitnessIdentityCardState
    extends State<CustomerFitnessIdentityCard> {
  _IdentityDisplay? _identity;
  bool _loading = true;
  bool _sharing = false;

  final GlobalKey _shareBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadFitnessIdentity();
  }

  Future<void> _loadFitnessIdentity() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _identity = null;
          _loading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final identity = _identityFromUserData(data);

      if (!mounted) return;

      setState(() {
        _identity = identity;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading fitness identity: $e');

      if (!mounted) return;

      setState(() {
        _identity = null;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToQuiz() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerQuizPage()),
    );

    if (!mounted) return;

    await _loadFitnessIdentity();
  }

  Future<void> _shareIdentity(_IdentityDisplay identity) async {
    if (_sharing) return;

    setState(() => _sharing = true);

    try {
      final bytes = await _buildCompactShareImageBytes(identity);

      await SharePlus.instance.share(
        ShareParams(
          subject: 'My Fitly fitness identity',
          text:
              'I’m ${identity.title} on Fitly — ${identity.tagline}\nFind your fitness identity on Fitly.',
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
      debugPrint('Share identity error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share badge. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  _IdentityDisplay? _identityFromUserData(Map<String, dynamic> data) {
    final v2 = data['fitnessIdentityV2'];

    // Main source of truth after schema cleanup.
    if (v2 is Map) {
      final key = _normaliseIdentityKey(
        v2['archetypeId'] ?? v2['key'] ?? data['fitnessIdentity'],
      );

      if (key.isNotEmpty) {
        final blindSpot = v2['blindSpot'];
        final recommended = v2['recommendedTrainerStyles'];
        final primaryTrainer =
            recommended is Map ? recommended['primary'] : null;
        final secondaryTrainer =
            recommended is Map ? recommended['secondary'] : null;

        return _displayForKey(key).copyWith(
          title: _asString(v2['archetypeName'] ?? v2['title']),
          tagline: _asString(v2['tagline']),
          shortMeaning: _asString(v2['shortMeaning']),
          trainerMatch: _asString(v2['trainerMatch']),
          assetPath: _asString(v2['badgeAsset'] ?? v2['assetPath']),
          blindSpotTitle: blindSpot is Map
              ? _asString(blindSpot['title'])
              : _asString(v2['blindSpotTitle']),
          blindSpotDescription: blindSpot is Map
              ? _asString(blindSpot['description'])
              : _asString(v2['blindSpotDescription']),
          bestTrainerStyleName: primaryTrainer is Map
              ? _asString(primaryTrainer['name'])
              : _asString(v2['bestTrainerStyleName']),
          secondaryTrainerStyleName: secondaryTrainer is Map
              ? _asString(secondaryTrainer['name'])
              : _asString(v2['secondaryTrainerStyleName']),
        );
      }
    }

    // Legacy fallback only. This keeps old users safe while the app moves to
    // fitnessIdentityV2 as the source of truth.
    final oldResult = data['customerQuizResult'];
    if (oldResult is Map) {
      final key = _normaliseIdentityKey(
        oldResult['key'] ?? data['fitnessIdentity'] ?? data['customerIdentity'],
      );

      if (key.isNotEmpty) {
        return _displayForKey(key).copyWith(
          title: _asString(oldResult['title']),
          tagline: _asString(oldResult['tagline']),
          shortMeaning: _asString(oldResult['shortMeaning']),
          trainerMatch: _asString(oldResult['trainerMatch']),
          assetPath: _asString(oldResult['assetPath']),
          blindSpotTitle: _asString(oldResult['blindSpotTitle']),
          blindSpotDescription: _asString(oldResult['blindSpotDescription']),
          bestTrainerStyleName: _asString(oldResult['bestTrainerStyleName']),
          secondaryTrainerStyleName:
              _asString(oldResult['secondaryTrainerStyleName']),
        );
      }
    }

    final fallbackKey = _normaliseIdentityKey(
      data['fitnessIdentity'] ?? data['fitnessBadge'],
    );

    if (fallbackKey.isEmpty) return null;

    return _displayForKey(fallbackKey);
  }

  String _asString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _normaliseIdentityKey(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';

    if (raw.isEmpty) return '';

    final cleaned = raw
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (cleaned.startsWith('the_')) return cleaned;

    return 'the_$cleaned';
  }

  _IdentityDisplay _displayForKey(String key) {
    return _identityLibrary[key] ??
        _IdentityDisplay(
          key: key,
          title: _titleFromKey(key),
          tagline: 'Your fitness identity.',
          shortMeaning:
              'This result helps Fitly understand your training style and what support suits you best.',
          trainerMatch:
              'We will use this to improve trainer matching as Fitly grows.',
          assetPath: 'assets/badges/customers/$key.png',
          accent: _gold,
          fallbackIcon: Icons.shield_rounded,
          blindSpotTitle: 'Your pattern',
          blindSpotDescription:
              'Fitly uses your answers to understand what support helps you stay consistent.',
          bestTrainerStyleName: 'Matching trainer style',
          secondaryTrainerStyleName: '',
        );
  }

  String _titleFromKey(String key) {
    final words = key
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return words.isEmpty ? 'Fitness Identity' : words;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _IdentityLoadingCard();
    }

    final identity = _identity;

    if (identity == null) {
      return _EmptyIdentityCard(onPressed: _navigateToQuiz);
    }

    return _UnlockedIdentityCard(
      identity: identity,
      shareBoundaryKey: _shareBoundaryKey,
      sharing: _sharing,
      onRetake: _navigateToQuiz,
      onShare: () => _shareIdentity(identity),
    );
  }
}

/* ───────────────── Identity model/library ───────────────── */

class _IdentityDisplay {
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
  final String bestTrainerStyleName;
  final String secondaryTrainerStyleName;

  const _IdentityDisplay({
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
    required this.bestTrainerStyleName,
    required this.secondaryTrainerStyleName,
  });

  _IdentityDisplay copyWith({
    String? title,
    String? tagline,
    String? shortMeaning,
    String? trainerMatch,
    String? assetPath,
    String? blindSpotTitle,
    String? blindSpotDescription,
    String? bestTrainerStyleName,
    String? secondaryTrainerStyleName,
  }) {
    return _IdentityDisplay(
      key: key,
      title: title != null && title.isNotEmpty ? title : this.title,
      tagline: tagline != null && tagline.isNotEmpty ? tagline : this.tagline,
      shortMeaning: shortMeaning != null && shortMeaning.isNotEmpty
          ? shortMeaning
          : this.shortMeaning,
      trainerMatch: trainerMatch != null && trainerMatch.isNotEmpty
          ? trainerMatch
          : this.trainerMatch,
      assetPath: assetPath != null && assetPath.isNotEmpty
          ? assetPath
          : this.assetPath,
      accent: accent,
      fallbackIcon: fallbackIcon,
      blindSpotTitle: blindSpotTitle != null && blindSpotTitle.isNotEmpty
          ? blindSpotTitle
          : this.blindSpotTitle,
      blindSpotDescription:
          blindSpotDescription != null && blindSpotDescription.isNotEmpty
              ? blindSpotDescription
              : this.blindSpotDescription,
      bestTrainerStyleName:
          bestTrainerStyleName != null && bestTrainerStyleName.isNotEmpty
              ? bestTrainerStyleName
              : this.bestTrainerStyleName,
      secondaryTrainerStyleName: secondaryTrainerStyleName != null &&
              secondaryTrainerStyleName.isNotEmpty
          ? secondaryTrainerStyleName
          : this.secondaryTrainerStyleName,
    );
  }
}

const Map<String, _IdentityDisplay> _identityLibrary = {
  'the_comeback': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Guide',
    secondaryTrainerStyleName: 'The Anchor',
  ),
  'the_momentum': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleName: 'The Guide',
  ),
  'the_strong': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleName: 'The Challenger',
  ),
  'the_glow_up': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Sculptor',
    secondaryTrainerStyleName: 'The Builder',
  ),
  'the_edge': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Challenger',
    secondaryTrainerStyleName: 'The Sculptor',
  ),
  'the_balance': _IdentityDisplay(
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
    bestTrainerStyleName: 'The Anchor',
    secondaryTrainerStyleName: 'The Guide',
  ),

  // Legacy compatibility only.
  'the_ascent': _IdentityDisplay(
    key: 'the_ascent',
    title: 'The Ascent',
    tagline: 'Rise higher.',
    shortMeaning: 'You are driven by growth, ambition, and visible progress.',
    trainerMatch:
        'Best with a trainer who sets milestones and pushes progression.',
    assetPath: 'assets/badges/customers/the_ascent.png',
    accent: Color(0xFFD8A339),
    fallbackIcon: Icons.terrain_rounded,
    blindSpotTitle: 'The Plateau Loop',
    blindSpotDescription:
        'You may need clearer progression to keep moving forward.',
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleName: 'The Challenger',
  ),
  'the_pulse': _IdentityDisplay(
    key: 'the_pulse',
    title: 'The Pulse',
    tagline: 'Move with energy.',
    shortMeaning: 'You need variety, movement, and sessions that feel alive.',
    trainerMatch: 'Best with an active trainer who keeps things engaging.',
    assetPath: 'assets/badges/customers/the_pulse.png',
    accent: Color(0xFF78A83D),
    fallbackIcon: Icons.monitor_heart_rounded,
    blindSpotTitle: 'The Boredom Dip',
    blindSpotDescription:
        'You may lose interest when training feels repetitive.',
    bestTrainerStyleName: 'The Challenger',
    secondaryTrainerStyleName: 'The Builder',
  ),
  'the_forge': _IdentityDisplay(
    key: 'the_forge',
    title: 'The Forge',
    tagline: 'Build discipline.',
    shortMeaning: 'You need structure, accountability, and a real system.',
    trainerMatch: 'Best with a structured trainer who sets standards.',
    assetPath: 'assets/badges/customers/the_forge.png',
    accent: Color(0xFFD8A339),
    fallbackIcon: Icons.construction_rounded,
    blindSpotTitle: 'The Discipline Gap',
    blindSpotDescription:
        'You may need structure and accountability to turn intention into action.',
    bestTrainerStyleName: 'The Builder',
    secondaryTrainerStyleName: 'The Guide',
  ),
};

/* ───────────────── Compact share image ───────────────── */

Future<Uint8List> _buildCompactShareImageBytes(
    _IdentityDisplay identity) async {
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

  final glowPaint = Paint()..color = identity.accent.withValues(alpha: 0.18);
  canvas.drawCircle(const Offset(615, 130), 180, glowPaint);
  canvas.drawCircle(
      Offset.zero, 190, Paint()..color = _brandColor.withValues(alpha: 0.08));
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
    'FITLY FITNESS IDENTITY',
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
    title: 'WHAT THIS MEANS',
    body: identity.shortMeaning,
    accent: identity.accent,
  );

  _drawShareInfoBox(
    canvas,
    y: 900,
    title: 'TRAINER FIT',
    body: identity.trainerMatch,
    accent: identity.accent,
  );

  _drawCenteredText(
    canvas,
    'Find your fitness identity on Fitly',
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

/* ───────────────── UI cards ───────────────── */

class _UnlockedIdentityCard extends StatelessWidget {
  final _IdentityDisplay identity;
  final GlobalKey shareBoundaryKey;
  final bool sharing;
  final VoidCallback onRetake;
  final VoidCallback onShare;

  const _UnlockedIdentityCard({
    required this.identity,
    required this.shareBoundaryKey,
    required this.sharing,
    required this.onRetake,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepaintBoundary(
          key: shareBoundaryKey,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: identity.accent.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                colors: [
                  identity.accent.withValues(alpha: 0.18),
                  _surface,
                  _ink,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: identity.accent.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -64,
                  top: -68,
                  child: Container(
                    width: 185,
                    height: 185,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: identity.accent.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned(
                  left: -90,
                  bottom: -100,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _brandColor.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _PremiumLabel(
                          text: 'FITNESS IDENTITY',
                          color: identity.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _BadgeShowcase(identity: identity),
                      const SizedBox(height: 14),
                      Text(
                        identity.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        identity.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: identity.accent,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MeaningBox(
                        title: 'What this means',
                        text: identity.shortMeaning,
                        accent: identity.accent,
                      ),
                      const SizedBox(height: 10),
                      _MeaningBox(
                        title: 'Blind spot',
                        text:
                            '${identity.blindSpotTitle}: ${identity.blindSpotDescription}',
                        accent: identity.accent,
                      ),
                      const SizedBox(height: 10),
                      _MeaningBox(
                        title: 'Trainer fit',
                        text: identity.trainerMatch,
                        accent: identity.accent,
                      ),
                      if (identity.secondaryTrainerStyleName.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MeaningBox(
                          title: 'Best styles',
                          text:
                              '${identity.bestTrainerStyleName} first, ${identity.secondaryTrainerStyleName} as a secondary fit.',
                          accent: identity.accent,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _FitlyShareFooter(accent: identity.accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Retake Quiz',
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
    );
  }
}

class _EmptyIdentityCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmptyIdentityCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumLabel(text: 'FITNESS IDENTITY'),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.11),
                    border: Border.all(color: _gold.withValues(alpha: 0.24)),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: _gold,
                    size: 46,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover your fitness personality',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Unlock your badge and help Fitly understand what kind of trainer suits you.',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _PrimaryButton(
                label: 'Take Quiz',
                icon: Icons.auto_awesome_rounded,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityLoadingCard extends StatelessWidget {
  const _IdentityLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          SizedBox(height: 6),
          CircularProgressIndicator(color: _gold),
          SizedBox(height: 14),
          Text(
            'Loading fitness identity...',
            style: TextStyle(
              color: _textMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _BadgeShowcase extends StatelessWidget {
  final _IdentityDisplay identity;

  const _BadgeShowcase({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      height: 188,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            identity.accent.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: identity.accent.withValues(alpha: 0.23)),
        boxShadow: [
          BoxShadow(
            color: identity.accent.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(11),
      child: Image.asset(
        identity.assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(
              identity.fallbackIcon,
              color: identity.accent,
              size: 78,
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
            title,
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE7E9EE),
              fontSize: 13.8,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              'Find your fitness identity on Fitly',
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

/* ───────────────── Buttons/labels ───────────────── */

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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
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
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: Colors.black),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
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
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 50),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
