// lib/marketplace_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';

import 'app_update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'components/trainer_card.dart';
import 'trainer_home_page.dart';
import 'trainer_dashboard_page.dart';
import 'services/block_service.dart';
import 'signup_page.dart';
import 'concierge_match_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */

const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

// Distance choices; -1 = Any (no cap)
const List<int> kDistanceChoices = [2, 5, 10, 15, 25, 50, -1];
String _distanceLabel(int km) => km == -1 ? 'Any' : '$km km';

class MarketplacePage extends StatefulWidget {
  final bool guestMode;

  const MarketplacePage({
    super.key,
    this.guestMode = false,
  });

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> allSuburbs = [];
  Map<String, dynamic>? selectedSuburbData;
  String selectedSuburbText = '';

  bool useCurrentLocation = false;
  double? _currentLat;
  double? _currentLng;
  bool _locBusy = false;

  RangeValues priceRange = const RangeValues(20, 150);
  double maxDistance = 1000.0;
  int selectedDistance = 50;
  double minRating = 0.0;

  final List<Map<String, dynamic>> priceRangeOptions = [
    {'label': '\$20–\$50', 'range': const RangeValues(20, 50)},
    {'label': '\$51–\$100', 'range': const RangeValues(51, 100)},
    {'label': '\$101–\$150', 'range': const RangeValues(101, 150)},
  ];

  final Map<String, Color> categoryColors = {
    'Strength Training': Colors.blue,
    'Recovery': Colors.green,
    'Yoga': Colors.purple,
    'Group Training': Colors.orange,
    'Pilates': Colors.pink,
    'Cardio': Colors.red,
    'HIIT': Colors.teal,
    'Endurance': Colors.amber,
    'Aerobics': Colors.cyan,
    'CrossFit': Colors.lime,
    'Dance Fitness': Colors.indigo,
    'Martial Arts': Colors.brown,
    'Weight Loss': Colors.lightGreen,
    'Pre/Post Pregnancy': Colors.deepPurple,
    'Other': Colors.grey,
  };

  List<String> selectedCategories = [];
  List<String> selectedTrainingMethods = [];

  List<Map<String, dynamic>> _allTrainers = [];

  String userRole = 'customer';
  List<String> _blocked = [];

  static const double kTileHeight = 305;

  // ---------------------------------------------------------------------------
  // LIFE-CYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadSuburbData();
    loadUserRole();
    _refreshBlocked();
  }

  Future<void> _refreshBlocked() async {
    _blocked = await BlockService.instance.blockedIds();
    if (mounted) setState(() {});
  }

  Future<void> loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(
      () => userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer',
    );
  }

  Future<void> loadSuburbData() async {
    try {
      final jsonData = await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> decoded = json.decode(jsonData);
      allSuburbs = List<Map<String, dynamic>>.from(decoded);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading suburbs: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MARKETPLACE QUALITY GATE
  // ---------------------------------------------------------------------------
  bool _hasText(String? s, {int minLen = 1}) {
    final t = (s ?? '').trim();
    return t.length >= minLen;
  }

  bool _hasAnyList(dynamic v) {
    if (v is List) {
      return v.where((e) => (e?.toString().trim() ?? '').isNotEmpty).isNotEmpty;
    }

    return false;
  }

  int _marketplaceQualityScore(Map<String, dynamic> t) {
    int score = 0;

    final photoUrl = (t['profileImageUrl'] ??
            t['photoURL'] ??
            t['photoUrl'] ??
            t['profilePhotoUrl'] ??
            t['avatarUrl'])
        ?.toString();

    if (_hasText(photoUrl)) score++;

    final bio = (t['description'] ?? t['bio'] ?? '').toString();
    if (_hasText(bio, minLen: 80)) score++;

    final headline = (t['headline'] ?? t['tagline'] ?? t['title'])?.toString();
    final specialties = t['specialties'] ?? t['services'] ?? t['focusAreas'];

    if (_hasText(headline) || _hasAnyList(specialties)) score++;

    final suburb =
        (t['suburb'] ?? t['location'] ?? t['city'] ?? '')?.toString();
    final postcode =
        (t['postcode'] ?? t['postCode'] ?? t['zip'] ?? '')?.toString();

    if (_hasText(suburb) || _hasText(postcode)) score++;

    return score;
  }

  bool _shouldShowInMarketplace(Map<String, dynamic> t) {
    final hidden = (t['isHidden'] == true) || (t['profileHidden'] == true);
    if (hidden) return false;

    return _marketplaceQualityScore(t) >= 2;
  }

  // ---------------------------------------------------------------------------
  // LOCATION HELPERS
  // ---------------------------------------------------------------------------
  Future<bool> _ensureLocation() async {
    setState(() => _locBusy = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showPremiumSnackBar(
          'Enable location services to use this feature.',
          error: true,
        );
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showPremiumSnackBar(
          'Location permission denied.',
          error: true,
        );
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentLat = pos.latitude;
      _currentLng = pos.longitude;

      return true;
    } catch (e) {
      debugPrint('Location error: $e');

      _showPremiumSnackBar(
        'Could not get your location.',
        error: true,
      );

      return false;
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // FILTER HELPERS
  // ---------------------------------------------------------------------------
  String _formatSuburb(Map<String, dynamic> item) =>
      '${item['Suburb']}, ${item['State']} (${item['Postcode']})';

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<Map<String, dynamic>> _filterTrainers(
    List<Map<String, dynamic>> trainers,
  ) {
    double? refLat;
    double? refLng;

    final onlyOnline = selectedTrainingMethods.length == 1 &&
        selectedTrainingMethods.contains('Online');

    if (!onlyOnline) {
      if (useCurrentLocation && _currentLat != null && _currentLng != null) {
        refLat = _currentLat;
        refLng = _currentLng;
      } else if (selectedSuburbData != null) {
        refLat =
            double.tryParse(selectedSuburbData!['Latitude'].toString()) ?? 0.0;
        refLng =
            double.tryParse(selectedSuburbData!['Longitude'].toString()) ?? 0.0;
      }
    }

    return trainers.where((t) {
      if (_blocked.contains(t['uid'])) return false;

      final rating = ((t['rating'] as num?)?.toDouble() ?? 0);
      final okRating = rating >= minRating;

      final specs = (t['specialties'] is List)
          ? (t['specialties'] as List).map((e) => e.toString()).toList()
          : <String>[];

      final okCat = selectedCategories.isEmpty ||
          selectedCategories.any(
            (c) => specs.map((e) => e.toLowerCase()).contains(
                  c.toLowerCase(),
                ),
          );

      var okPrice = true;
      final rateVal = t['rate'];
      final rate = (rateVal is num)
          ? rateVal.toDouble()
          : double.tryParse(rateVal?.toString() ?? '');

      if (rate != null) {
        okPrice = rate >= priceRange.start && rate <= priceRange.end;
      }

      var okDist = true;

      if (refLat != null && refLng != null) {
        final geo = t['geoLocation'];

        if (geo is Map && geo['lat'] != null && geo['lng'] != null) {
          final d = _distance(
            (geo['lat'] as num).toDouble(),
            (geo['lng'] as num).toDouble(),
            refLat,
            refLng,
          );

          okDist = d <= maxDistance;
        } else {
          final methods = (t['trainingMethods'] is List)
              ? (t['trainingMethods'] as List).map((e) => e.toString()).toList()
              : <String>[];

          final isOnlineCapable = methods.contains('Online');
          okDist = isOnlineCapable;
        }
      }

      final okMethod = selectedTrainingMethods.isEmpty ||
          selectedTrainingMethods.contains(t['method']) ||
          (t['trainingMethods'] is List &&
              (t['trainingMethods'] as List)
                  .any((m) => selectedTrainingMethods.contains(m)));

      return okCat && okRating && okPrice && okDist && okMethod;
    }).toList();
  }

  void clearFilters() {
    setState(() {
      selectedCategories.clear();
      selectedTrainingMethods.clear();
      selectedSuburbData = null;
      selectedSuburbText = '';
      selectedDistance = 50;
      minRating = 0;
      maxDistance = 1000;
      priceRange = const RangeValues(20, 150);
      useCurrentLocation = false;
      _currentLat = null;
      _currentLng = null;
    });
  }

  Chip _chip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      deleteIcon: const Icon(
        Icons.close_rounded,
        size: 16,
      ),
      deleteIconColor: _gold,
      onDeleted: onDeleted,
      backgroundColor: _surfaceRaised,
      side: BorderSide(
        color: _gold.withValues(alpha: 0.24),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (useCurrentLocation) {
      chips.add(
        _chip('Current location', () {
          setState(() {
            useCurrentLocation = false;
            _currentLat = null;
            _currentLng = null;
          });
        }),
      );
    } else if (selectedSuburbText.isNotEmpty) {
      chips.add(
        _chip(selectedSuburbText, () {
          setState(() {
            selectedSuburbData = null;
            selectedSuburbText = '';
          });
        }),
      );
    }

    if (selectedTrainingMethods.isNotEmpty) {
      chips.add(
        _chip(
          selectedTrainingMethods.join(', '),
          () => setState(() => selectedTrainingMethods.clear()),
        ),
      );
    }

    if (selectedCategories.isNotEmpty) {
      chips.add(
        _chip(
          selectedCategories.join(', '),
          () => setState(() => selectedCategories.clear()),
        ),
      );
    }

    if (minRating > 0) {
      chips.add(
        _chip(
          '${minRating.toStringAsFixed(1)}+ rating',
          () => setState(() => minRating = 0),
        ),
      );
    }

    if (selectedDistance != 50) {
      final label =
          selectedDistance == -1 ? 'Any distance' : '$selectedDistance km';

      chips.add(
        _chip(
          label,
          () {
            setState(() {
              selectedDistance = 50;
              maxDistance = 50;
            });
          },
        ),
      );
    }

    if (priceRange.start != 20 || priceRange.end != 150) {
      chips.add(
        _chip(
          '\$${priceRange.start.toInt()}–\$${priceRange.end.toInt()}/hr',
          () => setState(() => priceRange = const RangeValues(20, 150)),
        ),
      );
    }

    return chips;
  }

  // ---------------------------------------------------------------------------
  // FILTER SHEET
  // ---------------------------------------------------------------------------
  Future<void> showFilterDialog() async {
    int dDistance = selectedDistance;
    double dRating = minRating;
    Map<String, dynamic>? dSuburb = selectedSuburbData;
    String dSubText = selectedSuburbText;
    List<String> dMethods = List.from(selectedTrainingMethods);
    List<String> dCats = List.from(selectedCategories);
    RangeValues dPrice = priceRange;

    bool dUseCurrentLoc = useCurrentLocation;
    double? dLat = _currentLat;
    double? dLng = _currentLng;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                child: StatefulBuilder(
                  builder: (ctx, setStateDialog) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                          child: Column(
                            children: [
                              Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _gold.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _gold.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.tune_rounded,
                                      color: _gold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Filters',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Narrow down the right trainer.',
                                          style: TextStyle(
                                            color: _textMuted,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      Navigator.pop(ctx);
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: _line),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FilterSectionTitle(
                                  icon: Icons.my_location_rounded,
                                  title: 'Location',
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _surfaceRaised.withValues(
                                      alpha: 0.72,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _line),
                                  ),
                                  child: Row(
                                    children: [
                                      Switch(
                                        value: dUseCurrentLoc,
                                        activeThumbColor: _gold,
                                        activeTrackColor:
                                            _gold.withValues(alpha: 0.28),
                                        onChanged: (v) async {
                                          if (v) {
                                            setStateDialog(() {});
                                            final ok = await _ensureLocation();

                                            if (ok) {
                                              dUseCurrentLoc = true;
                                              dLat = _currentLat;
                                              dLng = _currentLng;
                                              dSuburb = null;
                                              dSubText = '';
                                            } else {
                                              dUseCurrentLoc = false;
                                            }
                                          } else {
                                            dUseCurrentLoc = false;
                                          }

                                          setStateDialog(() {});
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Use my current location',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (_locBusy)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _gold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AbsorbPointer(
                                  absorbing: dUseCurrentLoc,
                                  child: Opacity(
                                    opacity: dUseCurrentLoc ? 0.42 : 1,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () async {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();

                                        final selected = await Navigator.of(
                                          ctx,
                                          rootNavigator: true,
                                        ).push<Map<String, dynamic>>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                _MarketplaceLocationSearchPage(
                                              suburbsData: allSuburbs,
                                            ),
                                          ),
                                        );

                                        if (selected == null) return;

                                        setStateDialog(() {
                                          dUseCurrentLoc = false;
                                          dSuburb = selected;
                                          dSubText = _formatSuburb(selected);
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          13,
                                          14,
                                          13,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _ink,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: dSubText.isNotEmpty
                                                ? _gold.withValues(alpha: 0.40)
                                                : _line,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                dSubText.isEmpty
                                                    ? 'Select suburb or postcode'
                                                    : dSubText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: dSubText.isEmpty
                                                      ? _textMuted
                                                      : Colors.white,
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (dSubText.isNotEmpty)
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () {
                                                  setStateDialog(() {
                                                    dSubText = '';
                                                    dSuburb = null;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  color: _textMuted,
                                                  size: 19,
                                                ),
                                              )
                                            else
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: _textMuted,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _FilterSectionTitle(
                                  icon: Icons.fitness_center_rounded,
                                  title: 'Training method',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: ['Online', 'Face-to-Face'].map((m) {
                                    final sel = dMethods.contains(m);

                                    return _PremiumFilterChip(
                                      label: m,
                                      selected: sel,
                                      onSelected: (v) {
                                        setStateDialog(
                                          () => v
                                              ? dMethods.add(m)
                                              : dMethods.remove(m),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 22),
                                _FilterSectionTitle(
                                  icon: Icons.auto_awesome_rounded,
                                  title: 'Specialties',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: categoryColors.keys.map((c) {
                                    final sel = dCats.contains(c);

                                    return _PremiumFilterChip(
                                      label: c,
                                      selected: sel,
                                      onSelected: (v) {
                                        setStateDialog(
                                          () => v
                                              ? dCats.add(c)
                                              : dCats.remove(c),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 22),
                                if (!(dMethods.length == 1 &&
                                    dMethods.contains('Online'))) ...[
                                  _FilterSectionTitle(
                                    icon: Icons.route_rounded,
                                    title: 'Distance',
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: kDistanceChoices.map((km) {
                                      final selected = dDistance == km;

                                      return _PremiumChoiceChip(
                                        label: _distanceLabel(km),
                                        selected: selected,
                                        onSelected: (_) {
                                          setStateDialog(
                                            () => dDistance = km,
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 22),
                                ],
                                _FilterSectionTitle(
                                  icon: Icons.star_rounded,
                                  title: 'Minimum rating',
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _ink,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _line),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<double>(
                                      value: dRating,
                                      dropdownColor: _surfaceRaised,
                                      iconEnabledColor: _gold,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      onChanged: (v) {
                                        setStateDialog(() => dRating = v!);
                                      },
                                      items: [0.0, 3.0, 4.0, 4.5, 5.0]
                                          .map(
                                            (r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(
                                                r == 0 ? 'All ratings' : '$r+',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _FilterSectionTitle(
                                  icon: Icons.payments_outlined,
                                  title: 'Price range',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: priceRangeOptions.map((opt) {
                                    final range = opt['range'] as RangeValues;

                                    final sel = dPrice.start == range.start &&
                                        dPrice.end == range.end;

                                    return _PremiumChoiceChip(
                                      label: opt['label'].toString(),
                                      selected: sel,
                                      onSelected: (v) {
                                        if (v) {
                                          setStateDialog(
                                            () => dPrice = range,
                                          );
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          decoration: const BoxDecoration(
                            color: _surface,
                            border: Border(
                              top: BorderSide(color: _line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SecondaryButton(
                                  label: 'Clear',
                                  icon: Icons.refresh_rounded,
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    clearFilters();
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PrimaryButton(
                                  label: 'Apply',
                                  icon: Icons.check_rounded,
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();

                                    setState(() {
                                      selectedDistance = dDistance;
                                      minRating = dRating;
                                      selectedSuburbData = dSuburb;
                                      selectedSuburbText = dSubText;
                                      selectedTrainingMethods =
                                          List.from(dMethods);
                                      selectedCategories = List.from(dCats);
                                      maxDistance = (dDistance == -1)
                                          ? 100000.0
                                          : dDistance.toDouble();
                                      priceRange = dPrice;

                                      useCurrentLocation = dUseCurrentLoc;
                                      _currentLat = dLat;
                                      _currentLng = dLng;
                                    });

                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAV / SEARCH
  // ---------------------------------------------------------------------------
  Future<void> _showSearch(BuildContext context) async {
    showSearch(
      context: context,
      delegate: TrainerSearchDelegate(_allTrainers, userRole),
    );
  }

  Widget _buildBottomNavigation() {
    final isTrainer = userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer';

    return isTrainer
        ? const BottomNavigation(currentIndex: 0)
        : const BottomNavigationCustomers(currentIndex: 0);
  }

  // ---------------------------------------------------------------------------
  // LONG-PRESS BLOCK
  // ---------------------------------------------------------------------------
  void _showTrainerOptions(BuildContext ctx, Map<String, dynamic> trainer) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _line),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: _danger,
                    ),
                  ),
                  title: const Text(
                    'Block trainer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: const Text(
                    'Hide this trainer from your marketplace.',
                    style: TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);

                    await BlockService.instance.block(trainer['uid']);

                    if (!mounted) return;

                    setState(() => _blocked.add(trainer['uid']));

                    _showPremiumSnackBar('Trainer blocked');
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EXTRA WIDGETS
  // ---------------------------------------------------------------------------
  Widget _helperTile() {
    return SizedBox(
      height: kTileHeight,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ConciergeMatchPage(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _gold.withValues(alpha: 0.38),
            ),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2A2112),
                Color(0xFF151318),
                Color(0xFF0B0C0F),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -34,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold.withValues(alpha: 0.14),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 31,
                      color: _gold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Need help finding the right trainer?',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tell us what you’re looking for and Fitly will help connect you with a suitable trainer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12.2,
                      height: 1.32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Find my trainer',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signupTrainerBanner() {
    final user = FirebaseAuth.instance.currentUser;
    final guest = user == null || user.isAnonymous;

    if (!guest) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _gold.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: _gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you a trainer?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Join Fitly and get discovered.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleJoinAsTrainer,
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showBecomeTrainerConfirmDialog() async {
    return await showDialog<bool>(
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              Icons.fitness_center_rounded,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Become a trainer?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'You’re currently using a customer account. This will switch your role and create a trainer profile.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 14.5,
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
                                      Navigator.pop(dialogCtx, false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PrimaryButton(
                                  label: 'Yes',
                                  icon: Icons.check_rounded,
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
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
  }

  Future<void> _handleJoinAsTrainer() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SignupPage(preselectedRole: 'trainer'),
        ),
      );
      return;
    }

    if (userRole != 'trainer' &&
        userRole != 'personal trainer' &&
        userRole != 'personaltrainer') {
      final confirm = await _showBecomeTrainerConfirmDialog();

      if (!confirm) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'role': 'trainer'}, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', 'trainer');

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .set({
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => userRole = 'trainer');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const TrainerHomePage(showProfileCompleteMessage: false),
      ),
    );
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _gold,
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _danger.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Couldn’t load trainers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasHiddenProfiles}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.11),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: _gold,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No trainers found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasHiddenProfiles
                    ? 'No trainers match your filters. Some profiles are hidden because they are incomplete.'
                    : 'Try adjusting your filters or searching a nearby suburb.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: _SecondaryButton(
                  label: 'Clear filters',
                  icon: Icons.refresh_rounded,
                  onPressed: clearFilters,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerOnlyState() {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold.withValues(alpha: 0.11),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 38,
                      color: _gold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Marketplace is for customers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trainer accounts should use the dashboard and profile tools instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: _PrimaryButton(
                      label: 'Go to Dashboard',
                      icon: Icons.dashboard_rounded,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrainerDashboardPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: CircularProgressIndicator(color: _gold),
        ),
      );
    }

    if (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer') {
      return _buildTrainerOnlyState();
    }

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Image.asset(
          'assets/Fitly2.png',
          height: 58,
        ),
        centerTitle: true,
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
            ),
            onPressed: () => showFilterDialog(),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () => _showSearch(context),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _surface,
        onRefresh: () async => _refreshBlocked(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _signupTrainerBanner(),
              const AppUpdateBanner(),
              const SizedBox(height: 12),
              if (_buildActiveFilterChips().isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _buildActiveFilterChips()
                        .map(
                          (chip) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: chip,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trainer_profiles')
                      .snapshots(),
                  builder: (_, snap) {
                    if (snap.hasError) {
                      return _buildErrorState(snap.error);
                    }

                    if (!snap.hasData) {
                      return _buildLoadingState();
                    }

                    final allDocs =
                        snap.data!.docs.map<Map<String, dynamic>>((d) {
                      final m = d.data() as Map<String, dynamic>;
                      m['uid'] = d.id;
                      m['completed'] = (m['completed'] == true);
                      return m;
                    }).toList();

                    final docs = allDocs
                        .where((t) => !_blocked.contains(t['uid']))
                        .where(_shouldShowInMarketplace)
                        .toList();

                    docs.sort((a, b) {
                      final ca = (a['completed'] == true) ? 1 : 0;
                      final cb = (b['completed'] == true) ? 1 : 0;

                      if (ca != cb) return cb - ca;

                      final qa = _marketplaceQualityScore(a);
                      final qb = _marketplaceQualityScore(b);

                      if (qa != qb) return qb - qa;

                      final na = (a['name'] ?? a['displayName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final nb = (b['name'] ?? b['displayName'] ?? '')
                          .toString()
                          .toLowerCase();

                      return na.compareTo(nb);
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _allTrainers = docs;
                    });

                    final filtered = _filterTrainers(docs);

                    if (filtered.isEmpty) {
                      final hiddenCount = allDocs
                              .where((t) => !_blocked.contains(t['uid']))
                              .length -
                          docs.length;

                      return _buildEmptyState(
                        hasHiddenProfiles: hiddenCount > 0,
                      );
                    }

                    final listWithHelper = [
                      {'helperTile': true},
                      ...filtered,
                    ];

                    return GridView.builder(
                      cacheExtent: 800,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 18),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: kTileHeight,
                      ),
                      itemCount: listWithHelper.length,
                      itemBuilder: (_, i) {
                        final item = listWithHelper[i];

                        if (item['helperTile'] == true) {
                          return _helperTile();
                        }

                        final trainer = item;

                        final isTrainerRole = userRole == 'trainer' ||
                            userRole == 'personal trainer' ||
                            userRole == 'personaltrainer';

                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrainerHomePage(
                                  trainerData: trainer,
                                  viewAsCustomer: !isTrainerRole,
                                ),
                              ),
                            );
                          },
                          onLongPress: () =>
                              _showTrainerOptions(context, trainer),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: TrainerCard(
                              name: trainer['name'] ??
                                  trainer['displayName'] ??
                                  '',
                              specialties: List<String>.from(
                                  trainer['specialties'] ?? []),
                              location: trainer['location'] ??
                                  trainer['suburb'] ??
                                  '',
                              categoryColors: categoryColors,
                              profileImageUrl: (trainer['profileImageUrl'] ??
                                      trainer['photoURL'] ??
                                      trainer['photoUrl'] ??
                                      '')
                                  .toString(),
                              trainerData: trainer,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}

// ---------------------------------------------------------------------------
// FULL-SCREEN LOCATION SEARCH
// ---------------------------------------------------------------------------
class _MarketplaceLocationSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> suburbsData;

  const _MarketplaceLocationSearchPage({
    required this.suburbsData,
  });

  @override
  State<_MarketplaceLocationSearchPage> createState() =>
      _MarketplaceLocationSearchPageState();
}

class _MarketplaceLocationSearchPageState
    extends State<_MarketplaceLocationSearchPage> {
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

    final matches = widget.suburbsData.where((item) {
      final suburb = item['Suburb']?.toString().toLowerCase() ?? '';
      final state = item['State']?.toString().toLowerCase() ?? '';
      final postcode = item['Postcode']?.toString() ?? '';

      return suburb.contains(query) ||
          state.contains(query) ||
          postcode.contains(query);
    }).toList()
      ..sort(
        (a, b) => a['Suburb'].toString().compareTo(
              b['Suburb'].toString(),
            ),
      );

    setState(() => _results = matches.take(50).toList());
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
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
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
                  fillColor: _surfaceRaised,
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

// ---------------------------------------------------------------------------
// SEARCH DELEGATE
// ---------------------------------------------------------------------------
class TrainerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> trainers;
  final String userRole;

  TrainerSearchDelegate(this.trainers, this.userRole);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: _ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: _textMuted),
        border: InputBorder.none,
      ),
      textTheme: Theme.of(context).textTheme.copyWith(
            titleLarge: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
    );
  }

  @override
  String get searchFieldLabel => 'Search trainers';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      );

  @override
  List<Widget> buildActions(BuildContext _) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded, color: Colors.white),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext ctx) {
    final q = query.toLowerCase().trim();

    final results = trainers
        .where(
          (t) => (t['name'] ?? t['displayName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(q),
        )
        .toList();

    return _list(ctx, results);
  }

  @override
  Widget buildSuggestions(BuildContext ctx) {
    final q = query.toLowerCase().trim();

    final sugg = q.isEmpty
        ? trainers
        : trainers
            .where(
              (t) => (t['name'] ?? t['displayName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .startsWith(q),
            )
            .toList();

    return _list(ctx, sugg);
  }

  Widget _list(BuildContext ctx, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        color: _ink,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _line),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: _gold,
                    size: 42,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No trainers found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Try searching a different name.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: _ink,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final trainer = items[i];

          final name = (trainer['name'] ?? trainer['displayName'] ?? '')
              .toString()
              .trim();

          final location =
              (trainer['location'] ?? trainer['suburb'] ?? '').toString();

          final profileImageUrl = (trainer['profileImageUrl'] ??
                  trainer['photoURL'] ??
                  trainer['photoUrl'] ??
                  '')
              .toString();

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final isTrainerRole = userRole == 'trainer' ||
                  userRole == 'personal trainer' ||
                  userRole == 'personaltrainer';

              close(ctx, null);

              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => TrainerHomePage(
                    trainerData: trainer,
                    viewAsCustomer: !isTrainerRole,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_gold, Color(0xFF6F5422)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: _surfaceRaised,
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : const AssetImage('assets/default_profile.png')
                              as ImageProvider,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Trainer' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.isEmpty ? 'Location not listed' : location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _textMuted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ───────────────── Small premium widgets ───────────────── */

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

class _FilterSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FilterSectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PremiumFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _PremiumFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: _gold.withValues(alpha: 0.18),
      backgroundColor: _surfaceRaised,
      side: BorderSide(
        color: selected ? _gold.withValues(alpha: 0.5) : _line,
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

class _PremiumChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _PremiumChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: _gold.withValues(alpha: 0.18),
      backgroundColor: _surfaceRaised,
      side: BorderSide(
        color: selected ? _gold.withValues(alpha: 0.5) : _line,
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
