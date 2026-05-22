// lib/listings_page.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemUiOverlayStyle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_listing_page.dart';
import 'listing_detail_page.dart';
import 'bottom_navigation_customers.dart';
import 'marketplace_page.dart';
import 'bottom_navigation.dart';
import 'trainer_home_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF0B0D10);
const Color _surface = Color(0xFF171B22);
const Color _field = Color(0xFF252B35);
const Color _line = Color(0xFF343A46);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key});

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  String _trainingMethodFilter = 'all';

  int selectedDistance = 50;
  double maxDistance = 50.0;

  Map<String, dynamic>? selectedSuburbData;
  String selectedSuburbText = '';

  String userRole = 'customer';
  bool _roleChecked = false;

  List<Map<String, dynamic>> _suburbsData = [];

  final List<String> _trainingMethods = [
    'all',
    'online',
    'face-to-face',
  ];

  final List<int> _distanceOptions = [5, 10, 20, 50, 100];

  final Map<String, Future<_CustomerLite>> _customerCache = {};

  @override
  void initState() {
    super.initState();
    _loadSuburbs();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole')?.toLowerCase() ?? 'customer';

    if (!mounted) return;

    setState(() {
      userRole = role;
      _roleChecked = true;
    });

    debugPrint('ListingsPage: role loaded = $role');
  }

  Future<void> _loadSuburbs() async {
    try {
      final jsonString = await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

      if (!mounted) return;

      setState(() {
        _suburbsData = jsonData.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading suburbs data: $e');
    }
  }

  bool get _isTrainer {
    return userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer';
  }

  void _handleBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _isTrainer ? const TrainerHomePage() : const MarketplacePage(),
      ),
    );
  }

  Query _buildQuery() {
    return FirebaseFirestore.instance
        .collection('listings')
        .where('deleted', isEqualTo: false)
        .orderBy('timestamp', descending: true);
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  List<Map<String, dynamic>> _applyLocalFilters(
    List<Map<String, dynamic>> listings,
  ) {
    var result = listings;

    if (_trainingMethodFilter != 'all') {
      result = result.where((listing) {
        final method =
            (listing['trainingMethod'] ?? '').toString().toLowerCase();

        final legacyMethods = listing['trainingMethodPreference'];

        final legacyMatch = legacyMethods is List &&
            legacyMethods
                .map((e) => e.toString().toLowerCase())
                .contains(_trainingMethodFilter);

        if (_trainingMethodFilter == 'online') {
          return method == 'online' || method == 'both' || legacyMatch;
        }

        if (_trainingMethodFilter == 'face-to-face') {
          return method == 'face-to-face' || method == 'both' || legacyMatch;
        }

        return true;
      }).toList();
    }

    if (selectedSuburbData != null) {
      result = result.where((listing) {
        final geo = listing['geoLocation'];

        if (geo is Map) {
          final listingLat = (geo['lat'] as num?)?.toDouble() ?? 0.0;
          final listingLng = (geo['lng'] as num?)?.toDouble() ?? 0.0;

          final userLat =
              double.tryParse(selectedSuburbData!['Latitude'].toString()) ??
                  0.0;
          final userLng =
              double.tryParse(selectedSuburbData!['Longitude'].toString()) ??
                  0.0;

          final distance = calculateDistance(
            listingLat,
            listingLng,
            userLat,
            userLng,
          );

          return distance <= maxDistance;
        }

        return false;
      }).toList();
    }

    return result;
  }

  void clearFilters() {
    setState(() {
      _trainingMethodFilter = 'all';
      selectedSuburbData = null;
      selectedSuburbText = '';
      selectedDistance = 50;
      maxDistance = 50.0;
    });
  }

  String _formatSuburb(Map<String, dynamic> item) {
    return '${item['Suburb']}, ${item['State']} (${item['Postcode']})';
  }

  String _capitalize(String text) {
    final t = text.trimLeft();

    if (t.isEmpty) return text;

    final leadingSpaceCount = text.length - t.length;
    final leadingSpaces =
        leadingSpaceCount > 0 ? text.substring(0, leadingSpaceCount) : '';

    return leadingSpaces + t[0].toUpperCase() + t.substring(1);
  }

  Widget _buildBottomNavigation() {
    return _isTrainer
        ? const BottomNavigation(currentIndex: 2)
        : const BottomNavigationCustomers(currentIndex: 2);
  }

  Future<_CustomerLite> _customerForListing(Map<String, dynamic> data) async {
    final userId = (data['userId'] ?? '').toString();

    final fallbackName = (data['firstName'] ??
            data['displayName'] ??
            data['customerName'] ??
            'Customer')
        .toString();

    final fallbackImage =
        (data['profileImageUrl'] ?? data['photoURL'] ?? data['photoUrl'] ?? '')
            .toString();

    if (userId.isEmpty) {
      return _CustomerLite(
        name: fallbackName,
        profileImageUrl: fallbackImage,
      );
    }

    return _customerCache.putIfAbsent(userId, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!doc.exists) {
          return _CustomerLite(
            name: fallbackName,
            profileImageUrl: fallbackImage,
          );
        }

        final userData = doc.data() ?? <String, dynamic>{};

        final displayName = (userData['displayName'] ?? '').toString().trim();
        final firstName = (userData['firstName'] ?? '').toString().trim();
        final lastName = (userData['lastName'] ?? '').toString().trim();

        final fullName = '$firstName $lastName'.trim();

        final name = displayName.isNotEmpty
            ? displayName
            : fullName.isNotEmpty
                ? fullName
                : fallbackName;

        final imageUrl = (userData['profileImageUrl'] ??
                userData['photoURL'] ??
                userData['photoUrl'] ??
                fallbackImage)
            .toString();

        return _CustomerLite(
          name: name,
          profileImageUrl: imageUrl,
        );
      } catch (_) {
        return _CustomerLite(
          name: fallbackName,
          profileImageUrl: fallbackImage,
        );
      }
    });
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];

    if (selectedSuburbText.isNotEmpty) {
      chips.add(
        _FilterChip(
          label: selectedSuburbText,
          onDeleted: () {
            setState(() {
              selectedSuburbData = null;
              selectedSuburbText = '';
            });
          },
        ),
      );
    }

    if (_trainingMethodFilter != 'all') {
      chips.add(
        _FilterChip(
          label: _trainingMethodFilter == 'online' ? 'Online' : 'Face-to-face',
          onDeleted: () {
            setState(() {
              _trainingMethodFilter = 'all';
            });
          },
        ),
      );
    }

    if (selectedDistance != 50) {
      chips.add(
        _FilterChip(
          label: '$selectedDistance km',
          onDeleted: () {
            setState(() {
              selectedDistance = 50;
              maxDistance = 50.0;
            });
          },
        ),
      );
    }

    return chips;
  }

  Future<void> _openFilterSheet() async {
    String localMethod = _trainingMethodFilter;
    int localDistance = selectedDistance;
    Map<String, dynamic>? localSuburbData = selectedSuburbData;
    String localSuburbText = selectedSuburbText;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _line),
              ),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            height: 4,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(sheetCtx);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Narrow down listings by training method and location.',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 14.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SheetLabel('Training method'),
                        const SizedBox(height: 8),
                        Row(
                          children: _trainingMethods.map((method) {
                            final selected = localMethod == method;

                            final label = method == 'all'
                                ? 'All'
                                : method == 'online'
                                    ? 'Online'
                                    : 'Face-to-face';

                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right:
                                      method == _trainingMethods.last ? 0 : 8,
                                ),
                                child: _ChoiceBox(
                                  label: label,
                                  selected: selected,
                                  onTap: () {
                                    setStateDialog(() {
                                      localMethod = method;
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        const _SheetLabel('Location'),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();

                            final selected = await Navigator.of(sheetCtx,
                                    rootNavigator: true)
                                .push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (_) => _ListingsLocationSearchPage(
                                  suburbsData: _suburbsData,
                                ),
                              ),
                            );

                            if (selected == null) return;

                            setStateDialog(() {
                              localSuburbData = selected;
                              localSuburbText = _formatSuburb(selected);
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                            decoration: BoxDecoration(
                              color: _field,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: localSuburbText.isNotEmpty
                                    ? _gold.withValues(alpha: 0.40)
                                    : _line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    localSuburbText.isEmpty
                                        ? 'Select suburb or postcode'
                                        : localSuburbText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: localSuburbText.isEmpty
                                          ? _textMuted
                                          : Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (localSuburbText.isNotEmpty)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setStateDialog(() {
                                        localSuburbText = '';
                                        localSuburbData = null;
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
                        const SizedBox(height: 18),
                        const _SheetLabel('Distance'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _distanceOptions.map((distance) {
                            final selected = localDistance == distance;

                            return _DistanceChip(
                              label: '$distance km',
                              selected: selected,
                              onTap: () {
                                setStateDialog(() {
                                  localDistance = distance;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Clear',
                                onPressed: () {
                                  setStateDialog(() {
                                    localMethod = 'all';
                                    localDistance = 50;
                                    localSuburbData = null;
                                    localSuburbText = '';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PrimaryButton(
                                label: 'Apply',
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  setState(() {
                                    _trainingMethodFilter = localMethod;
                                    selectedDistance = localDistance;
                                    maxDistance = localDistance.toDouble();
                                    selectedSuburbText = localSuburbText;
                                    selectedSuburbData = localSuburbData;
                                  });

                                  Navigator.pop(sheetCtx);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateListing() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateListingPage(),
      ),
    );

    if (mounted) setState(() {});
  }

  bool _canCreateListing() {
    final user = FirebaseAuth.instance.currentUser;

    return user != null &&
        !user.isAnonymous &&
        user.emailVerified &&
        userRole == 'customer';
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleChecked) {
      return const Scaffold(
        backgroundColor: _ink,
        body: Center(
          child: CircularProgressIndicator(color: _gold),
        ),
      );
    }

    final query = _buildQuery();
    final activeChips = _activeFilterChips();

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _ink,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
        title: const Text(
          'Listings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _openFilterSheet,
            tooltip: 'Filters',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: Column(
        children: [
          if (activeChips.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) => activeChips[index],
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: activeChips.length,
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error);
                }

                if (!snapshot.hasData) {
                  return const _LoadingState();
                }

                final rawListings = snapshot.data!.docs.map((doc) {
                  return {
                    ...(doc.data() as Map<String, dynamic>),
                    'uid': doc.id,
                  };
                }).toList();

                final listings = _applyLocalFilters(rawListings);

                if (listings.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final data = listings[index];

                    final rawTitle = (data['title'] ?? 'No title').toString();
                    final title = _capitalize(rawTitle);
                    final description = (data['description'] ?? '').toString();
                    final location = (data['location'] ?? '').toString();

                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    final formattedTime = ts != null
                        ? DateFormat('dd MMM yyyy').format(ts.toDate())
                        : 'Unknown date';

                    final specialties = (data['specialties'] is List)
                        ? (data['specialties'] as List)
                            .map((e) => e.toString())
                            .toList()
                        : <String>[];

                    return FutureBuilder<_CustomerLite>(
                      future: _customerForListing(data),
                      builder: (context, customerSnap) {
                        final customer = customerSnap.data ??
                            const _CustomerLite(
                              name: 'Customer',
                              profileImageUrl: '',
                            );

                        return _ListingCard(
                          title: title,
                          creatorName: customer.name,
                          profileImageUrl: customer.profileImageUrl,
                          date: formattedTime,
                          description: description,
                          location: location,
                          specialties: specialties,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ListingDetailPage(
                                  listingData: data,
                                  listingId: data['uid'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreateListing()
          ? FloatingActionButton(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              elevation: 0,
              tooltip: 'Create a listing',
              onPressed: _openCreateListing,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}

/* ───────────────── Location Search Page ───────────────── */

class _ListingsLocationSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> suburbsData;

  const _ListingsLocationSearchPage({
    required this.suburbsData,
  });

  @override
  State<_ListingsLocationSearchPage> createState() =>
      _ListingsLocationSearchPageState();
}

class _ListingsLocationSearchPageState
    extends State<_ListingsLocationSearchPage> {
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
        .take(50)
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

/* ───────────────── Data model ───────────────── */

class _CustomerLite {
  final String name;
  final String profileImageUrl;

  const _CustomerLite({
    required this.name,
    required this.profileImageUrl,
  });
}

/* ───────────────── UI widgets ───────────────── */

class _ListingCard extends StatelessWidget {
  final String title;
  final String creatorName;
  final String profileImageUrl;
  final String date;
  final String description;
  final String location;
  final List<String> specialties;
  final VoidCallback onTap;

  const _ListingCard({
    required this.title,
    required this.creatorName,
    required this.profileImageUrl,
    required this.date,
    required this.description,
    required this.location,
    required this.specialties,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanDescription = description.trim();
    final cleanLocation = location.trim();

    final imageProvider = profileImageUrl.isNotEmpty
        ? NetworkImage(profileImageUrl)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'No title' : title.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'By $creatorName • $date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (cleanDescription.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                cleanDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (cleanLocation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                cleanLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: specialties.take(4).map((specialty) {
                  return _SpecialtyChip(label: specialty);
                }).toList(),
              ),
            ],
          ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      deleteIconColor: _gold,
      onDeleted: onDeleted,
      backgroundColor: _field,
      side: BorderSide(
        color: _gold.withValues(alpha: 0.25),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ChoiceBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceBox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.16) : _field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: 0.55) : _line,
          ),
        ),
        child: Text(
          label,
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

class _DistanceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DistanceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w900,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _line),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No listings available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try changing your filters or check back later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _danger.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) {
        return Container(
          height: 126,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Skeleton(width: 220, height: 18),
              const SizedBox(height: 12),
              _Skeleton(width: double.infinity, height: 12),
              const SizedBox(height: 8),
              _Skeleton(width: 260, height: 12),
              const Spacer(),
              _Skeleton(width: 170, height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double width;
  final double height;

  const _Skeleton({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
