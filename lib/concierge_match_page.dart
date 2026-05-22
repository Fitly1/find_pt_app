// lib/concierge_match_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'concierge_chat_page.dart';
import 'login_page.dart';
import 'signup_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */

const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class ConciergeMatchPage extends StatefulWidget {
  const ConciergeMatchPage({super.key});

  @override
  State<ConciergeMatchPage> createState() => _ConciergeMatchPageState();
}

class _ConciergeMatchPageState extends State<ConciergeMatchPage> {
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _goal = '';
  String _trainingPreference = '';
  String _budget = '';
  String _experience = '';
  bool _submitting = false;

  static const List<String> _goals = [
    'Lose weight',
    'Build muscle',
    'Get stronger',
    'Improve fitness',
    'Beginner support',
    'Injury/recovery support',
  ];

  static const List<String> _trainingPreferences = [
    'In person',
    'Online',
    'Either',
  ];

  static const List<String> _budgets = [
    'Under \$50/session',
    '\$50–\$80/session',
    '\$80–\$120/session',
    'Not sure',
  ];

  static const List<String> _experienceLevels = [
    'Beginner',
    'Returning',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _formReady =>
      _goal.isNotEmpty &&
      _trainingPreference.isNotEmpty &&
      _budget.isNotEmpty &&
      _experience.isNotEmpty &&
      _locationCtrl.text.trim().isNotEmpty;

  Future<void> _handleSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      await _showAuthRequiredSheet();
      return;
    }

    if (!_formReady) {
      _showSnackBar(
        'Answer the quick questions first.',
        error: true,
      );
      return;
    }

    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final config = await _loadConciergeConfig();

      if (!config.enabled) {
        _showSnackBar(
          'Fitly Concierge is currently unavailable.',
          error: true,
        );
        return;
      }

      if (config.adminUid.isEmpty) {
        _showSnackBar(
          'Concierge is not configured yet.',
          error: true,
        );
        return;
      }

      if (config.adminUid == user.uid) {
        _showSnackBar(
          'Use another customer account to test this request flow.',
          error: true,
        );
        return;
      }

      final customerName = await _resolveCustomerName(user);
      final conversationId = await _createConciergeConversation(
        customerUid: user.uid,
        customerName: customerName,
        conciergeAdminUid: config.adminUid,
        conciergeName: config.name,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConciergeChatPage(
            conversationId: conversationId,
            otherUserId: config.adminUid,
            lazyCreate: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Concierge submit failed: $e');
      _showSnackBar(
        'Could not send your concierge request. Plrease try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<_ConciergeConfig> _loadConciergeConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('fitly')
        .get();

    final data = doc.data() ?? <String, dynamic>{};

    return _ConciergeConfig(
      enabled: data['conciergeEnabled'] == true,
      name: (data['conciergeName'] ?? 'Fitly Concierge').toString().trim(),
      adminUid: (data['conciergeAdminUid'] ?? '').toString().trim(),
    );
  }

  Future<String> _resolveCustomerName(User user) async {
    final fallback = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Customer');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      final displayName = (data['displayName'] ??
              data['name'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
          .toString()
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');

      if (displayName.isNotEmpty) return displayName;
    } catch (_) {}

    return fallback;
  }

  Future<String> _createConciergeConversation({
    required String customerUid,
    required String customerName,
    required String conciergeAdminUid,
    required String conciergeName,
  }) async {
    final ids = [customerUid, conciergeAdminUid]..sort();
    final conversationId = '${ids[0]}_${ids[1]}';

    final firestore = FirebaseFirestore.instance;
    final conversationRef =
        firestore.collection('conversations').doc(conversationId);

    final location = _locationCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    final messageText = '''
Hi $conciergeName, I’m looking for a trainer.

Goal: $_goal
Training preference: $_trainingPreference
Location: $location
Budget: $_budget
Experience level: $_experience
Extra notes: ${notes.isEmpty ? 'Not provided' : notes}
'''
        .trim();

    final conversationSnap = await conversationRef.get();

    if (!conversationSnap.exists) {
      await conversationRef.set({
        'participants': [customerUid, conciergeAdminUid],
        'isConcierge': true,
        'customerId': customerUid,
        'customerName': customerName,
        'assignedAdminId': conciergeAdminUid,
        'conciergeName': conciergeName,
        'conciergeGoal': _goal,
        'conciergeTrainingPreference': _trainingPreference,
        'conciergeLocation': location,
        'conciergeBudget': _budget,
        'conciergeExperience': _experience,
        'status': 'open',
        'lastMessage': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadBy': [conciergeAdminUid],
      });
    } else {
      await conversationRef.set({
        'isConcierge': true,
        'customerId': customerUid,
        'customerName': customerName,
        'assignedAdminId': conciergeAdminUid,
        'conciergeName': conciergeName,
        'conciergeGoal': _goal,
        'conciergeTrainingPreference': _trainingPreference,
        'conciergeLocation': location,
        'conciergeBudget': _budget,
        'conciergeExperience': _experience,
        'status': 'open',
        'lastMessage': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadBy': [conciergeAdminUid],
      }, SetOptions(merge: true));
    }

    await conversationRef.collection('messages').add({
      'senderId': customerUid,
      'recipientId': conciergeAdminUid,
      'senderType': 'customer',
      'displayName': customerName,
      'text': messageText,
      'message': messageText,
      'type': 'text',
      'isConciergeRequest': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return conversationId;
  }

  Future<void> _showAuthRequiredSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 12),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_gold, Color(0xFF7A5A20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.black,
                        size: 33,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Create an account to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fitly needs an account so we can send your request and keep the chat connected to you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryButton(
                        label: 'Sign up as Customer',
                        icon: Icons.person_outline_rounded,
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupPage(
                                preselectedRole: 'customer',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _SecondaryButton(
                        label: 'I already have an account',
                        icon: Icons.login_rounded,
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text(
                        'Not now',
                        style: TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surfaceRaised,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: error ? _danger.withValues(alpha: 0.45) : _line,
          ),
        ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? _danger : _gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    final answered = [
      _goal,
      _trainingPreference,
      _budget,
      _experience,
      _locationCtrl.text.trim(),
    ].where((v) => v.isNotEmpty).length;

    final progress = answered / 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SmallLabel(text: 'FITLY CONCIERGE'),
          const SizedBox(height: 10),
          const Text(
            'Find the right trainer faster',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.55,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Answer a few quick questions. Fitly will send your request into a chat so we can help point you toward the right trainer.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 14.2,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: _gold,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: icon, title: title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              return _ChoicePill(
                label: option,
                selected: selected == option,
                onTap: () => setState(() => onChanged(option)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.location_on_outlined,
            title: 'Where should the trainer be based?',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            onChanged: (_) => setState(() {}),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Suburb or area, e.g. Blacktown',
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 14.5,
              ),
              filled: true,
              fillColor: _ink,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _gold,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.edit_note_rounded,
            title: 'Anything else? Optional',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            cursorColor: _gold,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText:
                  'Example: I prefer evenings, female trainer, gym-based, etc.',
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 14.2,
              ),
              filled: true,
              fillColor: _ink,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _gold,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final ready = _formReady && !_submitting;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: _ink,
        border: Border(
          top: BorderSide(color: _line),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: ready ? _handleSubmit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.3,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.black,
                    size: 19,
                  ),
            label: Text(
              _submitting ? 'Sending request...' : 'Send request to Fitly',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              disabledBackgroundColor: _surfaceRaised,
              disabledForegroundColor: _textMuted,
              foregroundColor: Colors.black,
              elevation: 0,
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Fitly Concierge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildProgressHeader(),
          const SizedBox(height: 12),
          _buildChoiceSection(
            title: 'What are you looking for?',
            icon: Icons.flag_rounded,
            options: _goals,
            selected: _goal,
            onChanged: (v) => _goal = v,
          ),
          const SizedBox(height: 12),
          _buildChoiceSection(
            title: 'How do you want to train?',
            icon: Icons.fitness_center_rounded,
            options: _trainingPreferences,
            selected: _trainingPreference,
            onChanged: (v) => _trainingPreference = v,
          ),
          const SizedBox(height: 12),
          _buildLocationSection(),
          const SizedBox(height: 12),
          _buildChoiceSection(
            title: 'What budget feels comfortable?',
            icon: Icons.payments_outlined,
            options: _budgets,
            selected: _budget,
            onChanged: (v) => _budget = v,
          ),
          const SizedBox(height: 12),
          _buildChoiceSection(
            title: 'Current fitness level?',
            icon: Icons.trending_up_rounded,
            options: _experienceLevels,
            selected: _experience,
            onChanged: (v) => _experience = v,
          ),
          const SizedBox(height: 12),
          _buildNotesSection(),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }
}

class _ConciergeConfig {
  final bool enabled;
  final String name;
  final String adminUid;
  const _ConciergeConfig({
    required this.enabled,
    required this.name,
    required this.adminUid,
  });
}

class _PremiumCard extends StatelessWidget {
  final Widget child;

  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final String text;

  const _SmallLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _gold.withValues(alpha: 0.94),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: _gold.withValues(alpha: 0.18),
      backgroundColor: _surfaceRaised,
      side: BorderSide(
        color: selected ? _gold.withValues(alpha: 0.55) : _line,
      ),
      labelStyle: TextStyle(
        color: selected ? _gold : Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
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
        minimumSize: const Size(0, 48),
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
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
