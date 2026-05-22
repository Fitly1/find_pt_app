import 'package:flutter/material.dart';

class TrainerDashboardIdentity {
  final String key;
  final String title;
  final String tagline;
  final String assetPath;
  final Color accent;
  final IconData fallbackIcon;

  const TrainerDashboardIdentity({
    required this.key,
    required this.title,
    required this.tagline,
    required this.assetPath,
    required this.accent,
    required this.fallbackIcon,
  });
}

class TrainerDashboardHeroCard extends StatelessWidget {
  final String displayName;
  final String imageUrl;
  final bool active;
  final bool paymentsEnabled;
  final int profileReadyPercent;
  final TrainerDashboardIdentity? identity;
  final VoidCallback onOpenEditProfile;

  const TrainerDashboardHeroCard({
    super.key,
    required this.displayName,
    required this.imageUrl,
    required this.active,
    required this.paymentsEnabled,
    required this.profileReadyPercent,
    required this.identity,
    required this.onOpenEditProfile,
  });

  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _textMain = Color(0xFFF5F6F8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DashboardAvatar(imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: paymentsEnabled
                              ? (active
                                  ? 'Membership: Active'
                                  : 'Membership: Inactive')
                              : (active
                                  ? 'Profile: Active'
                                  : 'Profile: Hidden'),
                          active: active,
                        ),
                        _MiniPill(
                          icon: Icons.trending_up_rounded,
                          label: '$profileReadyPercent% ready',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (identity == null)
            _IdentitySummaryPrompt(onTap: onOpenEditProfile)
          else
            _IdentitySummary(identity: identity!),
        ],
      ),
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  final String imageUrl;

  const _DashboardAvatar({required this.imageUrl});

  static const Color _raised = Color(0xFF20242C);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);

  @override
  Widget build(BuildContext context) {
    final ImageProvider imageProvider;

    if (imageUrl.trim().isNotEmpty) {
      imageProvider = NetworkImage(imageUrl.trim());
    } else {
      imageProvider = const AssetImage('assets/default_profile.png');
    }

    return Container(
      height: 66,
      width: 66,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gold, _goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: _raised,
        backgroundImage: imageProvider,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusPill({
    required this.label,
    required this.active,
  });

  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _success = Color(0xFF4CD17D);
  static const Color _danger = Color(0xFFE05A5A);

  @override
  Widget build(BuildContext context) {
    final color = active ? _success : _danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _textMain,
              fontSize: 12.3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({
    required this.icon,
    required this.label,
  });

  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _textMain,
              fontSize: 12.3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentitySummaryPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _IdentitySummaryPrompt({required this.onTap});

  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: _raisedSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: _gold,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Complete your coaching identity to improve your profile.',
              style: TextStyle(
                color: _textMuted,
                fontSize: 13.2,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: onTap,
            child: const Text(
              'Open',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentitySummary extends StatelessWidget {
  final TrainerDashboardIdentity identity;

  const _IdentitySummary({required this.identity});

  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: _raisedSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: identity.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: identity.accent.withValues(alpha: 0.11),
              border: Border.all(
                color: identity.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Image.asset(
              identity.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(
                  identity.fallbackIcon,
                  color: identity.accent,
                  size: 27,
                );
              },
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.title,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  identity.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: identity.accent,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Coaching identity active',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
