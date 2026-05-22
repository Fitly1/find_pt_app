// lib/listing_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart' as chat;
import 'profile_page.dart';
import 'feature_flags.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF0B0D10);
const Color _surface = Color(0xFF171B22);
const Color _field = Color(0xFF252B35);
const Color _line = Color(0xFF343A46);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class ListingDetailPage extends StatefulWidget {
  final Map<String, dynamic> listingData;
  final String listingId;

  const ListingDetailPage({
    super.key,
    required this.listingData,
    required this.listingId,
  });

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  bool? _isTrainer;
  bool? _isTrainerActive;

  String _customerName = 'Customer';
  String _customerImageUrl = '';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadCustomerLite();
  }

  String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _loadCustomerLite() async {
    final listingData = widget.listingData;
    final customerUid = _asString(listingData['userId']);

    final fallbackName = _asString(
      listingData['displayName'] ??
          listingData['firstName'] ??
          listingData['customerName'],
      fallback: 'Customer',
    );

    final fallbackImage = _asString(
      listingData['profileImageUrl'] ??
          listingData['photoURL'] ??
          listingData['photoUrl'],
    );

    if (customerUid.isEmpty) {
      if (!mounted) return;

      setState(() {
        _customerName = fallbackName;
        _customerImageUrl = fallbackImage;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerUid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;

        setState(() {
          _customerName = fallbackName;
          _customerImageUrl = fallbackImage;
        });
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};

      final displayName = _asString(data['displayName']);
      final firstName = _asString(data['firstName']);
      final lastName = _asString(data['lastName']);
      final fullName = '$firstName $lastName'.trim();

      final profileImageUrl = _asString(
        data['profileImageUrl'] ?? data['photoURL'] ?? data['photoUrl'],
      );

      if (!mounted) return;

      setState(() {
        _customerName = displayName.isNotEmpty
            ? displayName
            : fullName.isNotEmpty
                ? fullName
                : fallbackName;

        _customerImageUrl =
            profileImageUrl.isNotEmpty ? profileImageUrl : fallbackImage;
      });
    } catch (e) {
      debugPrint('Error loading customer details: $e');

      if (!mounted) return;

      setState(() {
        _customerName = fallbackName;
        _customerImageUrl = fallbackImage;
      });
    }
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isTrainer = false;
        _isTrainerActive = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;

        setState(() {
          _isTrainer = false;
          _isTrainerActive = false;
        });
        return;
      }

      final data = doc.data();
      final role = data?['role']?.toString().toLowerCase() ?? 'customer';

      final isTrainerNow = role == 'trainer' ||
          role == 'personal trainer' ||
          role == 'personaltrainer';

      if (!mounted) return;

      setState(() => _isTrainer = isTrainerNow);

      if (isTrainerNow) {
        await _checkTrainerActiveStatus();
      } else {
        if (!mounted) return;
        setState(() => _isTrainerActive = false);
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');

      if (!mounted) return;

      setState(() {
        _isTrainer = false;
        _isTrainerActive = false;
      });
    }
  }

  Future<void> _checkTrainerActiveStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => _isTrainerActive = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _isTrainerActive = false);
        return;
      }

      final data = doc.data();

      bool active = data?['isActive'] == true;

      if (!isTrainerPaymentsEnabled) {
        active = true;
      }

      if (!mounted) return;

      setState(() => _isTrainerActive = active);
    } catch (e) {
      debugPrint('Error fetching trainer active status: $e');

      if (!mounted) return;

      setState(() => _isTrainerActive = false);
    }
  }

  Future<void> _contactCustomer(String customerId) async {
    if (customerId.isEmpty) {
      _showPremiumSnackBar('Customer not found.', error: true);
      return;
    }

    if (_isTrainerActive == false) {
      await _showMembershipRequiredDialog();
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showPremiumSnackBar('Please sign in first.', error: true);
      return;
    }

    final trainerUid = currentUser.uid;
    final conversations =
        FirebaseFirestore.instance.collection('conversations');

    try {
      final query = await conversations
          .where('participants', arrayContains: trainerUid)
          .get();

      String? conversationId;

      for (final doc in query.docs) {
        final data = doc.data();

        final participants = (data['participants'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (participants.contains(customerId) &&
            participants.contains(trainerUid)) {
          conversationId = doc.id;
          break;
        }
      }

      if (conversationId == null) {
        final newConv = await conversations.add({
          'participants': [trainerUid, customerId],
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unreadBy': [customerId],
          'listingId': widget.listingId,
        });

        conversationId = newConv.id;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => chat.ChatPage(
            conversationId: conversationId!,
            otherUserId: customerId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error contacting customer: $e');

      if (!mounted) return;

      _showPremiumSnackBar('Could not open chat.', error: true);
    }
  }

  Future<void> _showMembershipRequiredDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogCtx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: Colors.transparent,
              child: Dialog(
                backgroundColor: _surface,
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: const BorderSide(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Membership required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Activate your trainer membership to contact customers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _SecondaryButton(
                              label: 'Cancel',
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PrimaryButton(
                              label: 'Activate',
                              onPressed: () {
                                Navigator.pop(dialogCtx);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPremiumSnackBar(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _field,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: error ? _danger.withValues(alpha: 0.45) : _line,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formattedDate(Map<String, dynamic> data) {
    final Timestamp? createdAtTs = data['createdAt'] as Timestamp?;
    final Timestamp? timestampTs = data['timestamp'] as Timestamp?;
    final Timestamp? ts = createdAtTs ?? timestampTs;

    if (ts == null) return 'Unknown date';

    return DateFormat('dd MMM yyyy').format(ts.toDate());
  }

  List<String> _readSpecialties(Map<String, dynamic> data) {
    final value = data['specialties'];

    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.listingData;

    final title = _asString(data['title'], fallback: 'No title');
    final goal = _asString(data['goal']);
    final description = _asString(data['description']);
    final location =
        _asString(data['location'], fallback: 'Location not listed');
    final trainingMethod =
        _asString(data['trainingMethod'], fallback: 'Not specified');
    final date = _formattedDate(data);
    final customerUid = _asString(data['userId']);
    final specialties = _readSpecialties(data);

    if (_isTrainer == null) {
      return const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: CircularProgressIndicator(color: _gold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Listing Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          _isTrainer == true ? 110 : 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MainListingCard(
              title: title,
              goal: goal,
              customerName: _customerName,
              customerImageUrl: _customerImageUrl,
              date: date,
            ),
            const SizedBox(height: 12),
            if (description.isNotEmpty) ...[
              _SimpleSection(
                title: 'Details',
                child: Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SimpleSection(
              title: 'Training request',
              child: Column(
                children: [
                  _InfoLine(label: 'Location', value: location),
                  const SizedBox(height: 10),
                  _InfoLine(label: 'Method', value: trainingMethod),
                  const SizedBox(height: 10),
                  _InfoLine(label: 'Posted', value: date),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SimpleSection(
              title: 'Specialties',
              child: specialties.isEmpty
                  ? const Text(
                      'Not specified',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: specialties.map((specialty) {
                        return _SpecialtyChip(label: specialty);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isTrainer == true
          ? _ContactFooter(
              isChecking: _isTrainerActive == null,
              isActive: _isTrainerActive == true,
              onPressed: () => _contactCustomer(customerUid),
            )
          : null,
    );
  }
}

/* ───────────────── Premium UI widgets ───────────────── */

class _MainListingCard extends StatelessWidget {
  final String title;
  final String goal;
  final String customerName;
  final String customerImageUrl;
  final String date;

  const _MainListingCard({
    required this.title,
    required this.goal,
    required this.customerName,
    required this.customerImageUrl,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = customerImageUrl.isNotEmpty
        ? NetworkImage(customerImageUrl)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goal.isNotEmpty) ...[
            _GoalPill(label: goal),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.32),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(1.5),
                child: CircleAvatar(
                  backgroundColor: _field,
                  backgroundImage: imageProvider,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'By $customerName • $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SimpleSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalPill extends StatelessWidget {
  final String label;

  const _GoalPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.26),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  final bool isChecking;
  final bool isActive;
  final VoidCallback onPressed;

  const _ContactFooter({
    required this.isChecking,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isChecking
        ? 'Checking profile...'
        : isActive
            ? 'Contact Customer'
            : 'Activate to Contact';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(
            top: BorderSide(color: _line),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isChecking ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              disabledBackgroundColor: _field,
              foregroundColor: Colors.black,
              disabledForegroundColor: _textMuted,
              elevation: 0,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.04),
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
    );
  }
}
