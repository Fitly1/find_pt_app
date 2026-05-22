// lib/create_listing_page.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemUiOverlayStyle;

import 'secure_storage_service.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF0B0D10);
const Color _surface = Color(0xFF171B22);
const Color _surfaceRaised = Color(0xFF222832);
const Color _field = Color(0xFF252B35);
const Color _line = Color(0xFF343A46);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class CreateListingPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? existingData;
  final String? listingId;

  const CreateListingPage({
    super.key,
    this.isEditing = false,
    this.existingData,
    this.listingId,
  });

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  String? _selectedGoal;
  String? _selectedSupportNeed;

  String _existingTitle = '';
  String _existingDescription = '';

  String? _selectedLocation;
  Map<String, dynamic>? _selectedSuburb;

  final List<String> _trainingMethods = ['Both', 'Online', 'Face-to-Face'];
  String _selectedTrainingMethod = 'Both';

  List<Map<String, dynamic>> _suburbsData = [];

  final List<String> _allSpecialties = [
    'Strength Training',
    'Recovery',
    'Yoga',
    'Group Training',
    'Pilates',
    'Cardio',
    'HIIT',
    'Endurance',
    'Aerobics',
    'CrossFit',
    'Dance Fitness',
    'Martial Arts',
    'Weight Loss',
    'Pre/Post Pregnancy',
    'Other',
  ];

  final List<String> _selectedSpecialties = [];

  final List<_GoalOption> _goalOptions = const [
    _GoalOption(
      label: 'Lose weight',
      title: 'I need help with weight loss',
      specialties: ['Weight Loss', 'Cardio'],
    ),
    _GoalOption(
      label: 'Build muscle',
      title: 'I want to build muscle',
      specialties: ['Strength Training'],
    ),
    _GoalOption(
      label: 'Get stronger',
      title: 'I want to get stronger',
      specialties: ['Strength Training'],
    ),
    _GoalOption(
      label: 'Improve fitness',
      title: 'I want to improve my fitness',
      specialties: ['Cardio', 'HIIT'],
    ),
    _GoalOption(
      label: 'Rebuild confidence',
      title: 'I want to rebuild confidence with training',
      specialties: ['Strength Training', 'Other'],
    ),
    _GoalOption(
      label: 'Return to training',
      title: 'I need help returning to training safely',
      specialties: ['Recovery'],
    ),
    _GoalOption(
      label: 'Not sure yet',
      title: 'I need help choosing the right training plan',
      specialties: ['Other'],
    ),
  ];

  final List<String> _supportOptions = const [
    'Accountability',
    'Clear plan',
    'Technique help',
    'Motivation',
    'Beginner friendly',
    'Injury-aware',
  ];

  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadSuburbs();

    if (widget.isEditing && widget.existingData != null) {
      final data = widget.existingData!;

      _existingTitle = (data['title'] ?? '').toString();
      _existingDescription = (data['description'] ?? '').toString();

      final existingGoal = (data['goal'] ?? '').toString().trim();
      _selectedGoal = existingGoal.isEmpty ? null : existingGoal;

      final existingSupport =
          (data['supportNeed'] ?? data['support'] ?? '').toString().trim();
      _selectedSupportNeed = existingSupport.isEmpty ? null : existingSupport;

      _selectedLocation = (data['location'] ?? '').toString();

      final existingMethod =
          (data['trainingMethod'] ?? _selectedTrainingMethod).toString();

      _selectedTrainingMethod =
          _trainingMethods.contains(existingMethod) ? existingMethod : 'Both';

      if (data['specialties'] is List) {
        _selectedSpecialties.addAll(
          (data['specialties'] as List).map((e) => e.toString()),
        );
      }
    }
  }

  Future<void> _loadSuburbs() async {
    try {
      final jsonString = await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

      if (!mounted) return;

      setState(() {
        _suburbsData = jsonData.map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (e) {
      debugPrint('Error loading suburbs data: $e');
    }
  }

  String _cap(String s) {
    final trimmed = s.trim();

    return trimmed.isEmpty
        ? trimmed
        : trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  bool get _hasLocation {
    return _selectedLocation != null && _selectedLocation!.trim().isNotEmpty;
  }

  _GoalOption? _selectedGoalOption() {
    if (_selectedGoal == null) return null;

    for (final option in _goalOptions) {
      if (option.label == _selectedGoal) return option;
    }

    return null;
  }

  String _effectiveTitle() {
    final option = _selectedGoalOption();

    if (option != null) return option.title;

    if (_existingTitle.trim().isNotEmpty) return _existingTitle.trim();

    return 'Customer training request';
  }

  String _effectiveDescription() {
    final parts = <String>[];

    if (_selectedGoal != null && _selectedGoal!.trim().isNotEmpty) {
      parts.add('Goal: $_selectedGoal.');
    }

    if (_selectedSupportNeed != null &&
        _selectedSupportNeed!.trim().isNotEmpty) {
      parts.add('Support needed: $_selectedSupportNeed.');
    }

    parts.add('Training preference: $_selectedTrainingMethod.');

    if (_existingDescription.trim().isNotEmpty &&
        widget.isEditing &&
        _selectedSupportNeed == null) {
      parts.add(_existingDescription.trim());
    }

    return parts.join(' ');
  }

  void _selectGoal(_GoalOption option) {
    setState(() {
      final alreadySelected = _selectedGoal == option.label;

      if (alreadySelected) {
        _selectedGoal = null;
        return;
      }

      _selectedGoal = option.label;

      for (final specialty in option.specialties) {
        if (!_selectedSpecialties.contains(specialty)) {
          _selectedSpecialties.add(specialty);
        }
      }
    });
  }

  Future<void> _openLocationSearch() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationSearchPage(
          suburbsData: _suburbsData,
        ),
      ),
    );

    if (selected == null) return;

    final display =
        '${selected['Suburb']}, ${selected['State']} (${selected['Postcode']})';

    if (!mounted) return;

    setState(() {
      _selectedLocation = display;
      _selectedSuburb = selected;
    });
  }

  Future<void> _submitListing() async {
    if (_selectedGoal == null || _selectedGoal!.trim().isEmpty) {
      _showPremiumSnackBar('Choose what you need help with.', error: true);
      return;
    }

    if (_selectedSupportNeed == null || _selectedSupportNeed!.trim().isEmpty) {
      _showPremiumSnackBar('Choose the support you need.', error: true);
      return;
    }

    if (!_hasLocation) {
      _showPremiumSnackBar('Please select a location.', error: true);
      return;
    }

    if (_selectedSpecialties.isEmpty) {
      _showPremiumSnackBar('Please select at least one specialty.',
          error: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showPremiumSnackBar('No user is logged in.', error: true);
      return;
    }

    final listingData = <String, dynamic>{
      'goal': _selectedGoal,
      'supportNeed': _selectedSupportNeed,
      'title': _cap(_effectiveTitle()),
      'description': _effectiveDescription(),
      'location': _selectedLocation,
      'trainingMethod': _selectedTrainingMethod,
      'specialties': _selectedSpecialties,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'deleted': false,
    };

    if (!widget.isEditing) {
      listingData['createdAt'] = FieldValue.serverTimestamp();
    }

    if (_selectedSuburb != null) {
      listingData['geoLocation'] = {
        'lat': double.tryParse(_selectedSuburb!['Latitude'].toString()) ?? 0.0,
        'lng': double.tryParse(_selectedSuburb!['Longitude'].toString()) ?? 0.0,
      };
    }

    try {
      if (widget.isEditing && widget.listingId != null) {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listingId)
            .update(listingData);
      } else {
        await FirebaseFirestore.instance
            .collection('listings')
            .add(listingData);
      }

      await secureStorage.writeData(
        'last_listing_submission',
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;

      _showPremiumSnackBar('Listing saved successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showPremiumSnackBar(
        'Error saving listing. Please try again.',
        error: true,
      );
      debugPrint('Error saving listing: $e');
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          builder: (dialogContext) {
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _danger.withValues(alpha: 0.13),
                              border: Border.all(
                                color: _danger.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: _danger,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Delete listing?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'This will remove the listing from Fitly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: _SecondaryButton(
                                  label: 'Cancel',
                                  icon: null,
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DangerButton(
                                  label: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
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
        ) ??
        false;

    if (!confirm) return;

    try {
      if (widget.listingId != null) {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listingId)
            .update({'deleted': true});
      }

      if (!mounted) return;

      _showPremiumSnackBar('Listing deleted');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showPremiumSnackBar('Could not delete listing.', error: true);
      debugPrint('Delete listing error: $e');
    }
  }

  void _showPremiumSnackBar(String message, {bool error = false}) {
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        automaticallyImplyLeading: true,
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isEditing ? 'Edit Listing' : 'Create Listing',
          style: const TextStyle(
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          child: Column(
            children: [
              _PageIntro(isEditing: isEditing),
              const SizedBox(height: 12),
              _PremiumSectionCard(
                title: 'What do you need help with?',
                subtitle: 'Pick the closest option.',
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _goalOptions.map((option) {
                      final selected = _selectedGoal == option.label;

                      return _OptionPill(
                        label: option.label,
                        selected: selected,
                        onTap: () => _selectGoal(option),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PremiumSectionCard(
                title: 'What kind of support do you need?',
                subtitle: 'This helps trainers know how to approach you.',
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _supportOptions.map((option) {
                      final selected = _selectedSupportNeed == option;

                      return _OptionPill(
                        label: option,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _selectedSupportNeed = selected ? null : option;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PremiumSectionCard(
                title: 'How do you want to train?',
                subtitle: 'Choose the format that suits you.',
                children: [
                  Row(
                    children: _trainingMethods.map((method) {
                      final selected = _selectedTrainingMethod == method;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: method == _trainingMethods.last ? 0 : 7,
                          ),
                          child: _MethodTile(
                            label: method,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                _selectedTrainingMethod = method;
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PremiumSectionCard(
                title: 'Location',
                subtitle: 'Choose the suburb or postcode trainers should know.',
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openLocationSearch,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _hasLocation
                              ? _gold.withValues(alpha: 0.36)
                              : _line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _hasLocation
                                  ? _selectedLocation!
                                  : 'Select suburb or postcode',
                              style: TextStyle(
                                color: _hasLocation ? Colors.white : _textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PremiumSectionCard(
                title: 'Trainer specialties',
                subtitle: 'Auto-filled from your goal. Adjust if needed.',
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _allSpecialties.map((s) {
                      final selected = _selectedSpecialties.contains(s);

                      return _OptionPill(
                        label: s,
                        selected: selected,
                        small: true,
                        onTap: () {
                          setState(() {
                            selected
                                ? _selectedSpecialties.remove(s)
                                : _selectedSpecialties.add(s);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: isEditing ? 'Save Changes' : 'Create Listing',
                  icon: isEditing
                      ? Icons.check_rounded
                      : Icons.add_circle_outline_rounded,
                  onPressed: _submitListing,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _DangerButton(
                    label: 'Delete Listing',
                    icon: Icons.delete_outline_rounded,
                    onPressed: _confirmDelete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Location Search Page ───────────────── */

class _LocationSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> suburbsData;

  const _LocationSearchPage({
    required this.suburbsData,
  });

  @override
  State<_LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<_LocationSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final matches = widget.suburbsData
        .where((item) {
          final suburb = item['Suburb']?.toString().toLowerCase() ?? '';
          final state = item['State']?.toString().toLowerCase() ?? '';
          final postcode = item['Postcode']?.toString() ?? '';

          return suburb.contains(query) ||
              state.contains(query) ||
              postcode.contains(query);
        })
        .take(40)
        .toList();

    setState(() => _results = matches);
  }

  String _formatSuburb(Map<String, dynamic> item) {
    return '${item['Suburb']}, ${item['State']} (${item['Postcode']})';
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
          'Search Location',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                cursorColor: _gold,
                onChanged: _search,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Type suburb or postcode',
                  hintStyle: const TextStyle(
                    color: _textMuted,
                    fontSize: 15.5,
                  ),
                  filled: true,
                  fillColor: _field,
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
              const SizedBox(height: 12),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().isEmpty
                              ? 'Start typing to search.'
                              : 'No suburbs found.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: _line),
                        itemBuilder: (_, index) {
                          final item = _results[index];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            title: Text(
                              _formatSuburb(item),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pop(context, item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Data models ───────────────── */

class _GoalOption {
  final String label;
  final String title;
  final List<String> specialties;

  const _GoalOption({
    required this.label,
    required this.title,
    required this.specialties,
  });
}

/* ───────────────── UI widgets ───────────────── */

class _PageIntro extends StatelessWidget {
  final bool isEditing;

  const _PageIntro({
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Text(
        isEditing
            ? 'Update your training request.'
            : 'Create a quick request so trainers know what you need.',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PremiumSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _PremiumSectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
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
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool small;
  final VoidCallback onTap;

  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12,
          vertical: small ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.16) : _field,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: 0.55) : _line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _gold : Colors.white,
            fontSize: small ? 13 : 14.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.16) : _field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: 0.55) : _line,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? _gold : Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
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
          : Icon(icon, size: 19, color: Colors.black),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 15.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
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
          fontSize: 15,
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

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _DangerButton({
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
          : Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _danger,
        foregroundColor: Colors.white,
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
