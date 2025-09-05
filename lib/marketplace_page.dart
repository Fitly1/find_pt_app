// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'components/trainer_card.dart';
import 'trainer_home_page.dart';
import 'splashpage.dart';
import 'listings_page.dart';
import 'services/block_service.dart';
import 'feature_flags.dart';

class MarketplacePage extends StatefulWidget {
  final bool guestMode;
  const MarketplacePage({super.key, this.guestMode = false});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  // ---------------------------------------------------------------------------
  //                               STATE & DATA
  // ---------------------------------------------------------------------------
  // Filtering variables
  List<Map<String, dynamic>> allSuburbs = [];
  Map<String, dynamic>? selectedSuburbData;
  String selectedSuburbText = '';

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
  final TextEditingController suburbController = TextEditingController();

  String userRole = 'customer';
  List<String> _blocked = [];

  // ---------------------------------------------------------------------------
  //                               LIFE-CYCLE
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
    setState(() =>
        userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer');
  }

  Future<void> loadSuburbData() async {
    try {
      final jsonData = await rootBundle.loadString('assets/Suburbs.json');
      allSuburbs = (json.decode(jsonData) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading suburbs: $e');
    }
  }

  // ---------------------------------------------------------------------------
  //                             HELPER FUNCTIONS
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
      List<Map<String, dynamic>> trainers) {
    return trainers.where((t) {
      if (_blocked.contains(t['uid'])) return false;

      final rating = ((t['rating'] as num?)?.toDouble() ?? 0);
      bool okRating = rating >= minRating;

      bool okCat = selectedCategories.isEmpty ||
          selectedCategories.any((c) => (t['specialties'] ?? [])
              .map((e) => e.toString().toLowerCase())
              .contains(c.toLowerCase()));

      bool okPrice = true;
      if (t['rate'] is num) {
        final rate = (t['rate'] as num).toDouble();
        okPrice = rate >= priceRange.start && rate <= priceRange.end;
      }

      bool okDist = true;
      if (selectedSuburbData != null) {
        final geo = t['geoLocation'];
        if (geo is Map) {
          final uLat =
              double.tryParse(selectedSuburbData!['Latitude'].toString()) ?? 0;
          final uLng =
              double.tryParse(selectedSuburbData!['Longitude'].toString()) ?? 0;
          okDist = _distance((geo['lat'] as num).toDouble(),
                  (geo['lng'] as num).toDouble(), uLat, uLng) <=
              maxDistance;
        } else {
          okDist = false;
        }
      }

      bool okMethod = selectedTrainingMethods.isEmpty ||
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
    });
  }

  Chip _chip(String label, VoidCallback onDeleted) =>
      Chip(label: Text(label), onDeleted: onDeleted);

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (selectedSuburbText.isNotEmpty) {
      chips.add(_chip('Suburb: $selectedSuburbText', () {
        setState(() {
          selectedSuburbData = null;
          selectedSuburbText = '';
        });
      }));
    }
    if (selectedTrainingMethods.isNotEmpty) {
      chips.add(_chip('Training: ${selectedTrainingMethods.join(', ')}',
          () => setState(() => selectedTrainingMethods.clear())));
    }
    if (selectedCategories.isNotEmpty) {
      chips.add(_chip('Specialties: ${selectedCategories.join(', ')}',
          () => setState(() => selectedCategories.clear())));
    }
    if (minRating > 0) {
      chips.add(_chip('Min Rating: ${minRating.toStringAsFixed(1)}+',
          () => setState(() => minRating = 0)));
    }
    if (selectedDistance != 50) {
      chips.add(_chip('Distance: $selectedDistance km', () {
        setState(() {
          selectedDistance = 50;
          maxDistance = 50;
        });
      }));
    }
    if (priceRange.start != 20 || priceRange.end != 150) {
      chips.add(_chip(
          'Price: \$${priceRange.start.toInt()}-\$${priceRange.end.toInt()}',
          () => setState(() => priceRange = const RangeValues(20, 150))));
    }
    return chips;
  }

// ---------------------------------------------------------------------------
//  FILTER DIALOG  (guests allowed)
// ---------------------------------------------------------------------------
  Future<void> showFilterDialog() async {
    int dDistance = selectedDistance;
    double dRating = minRating;
    Map<String, dynamic>? dSuburb = selectedSuburbData;
    String dSubText = selectedSuburbText;
    List<String> dMethods = List.from(selectedTrainingMethods);
    List<String> dCats = List.from(selectedCategories);
    RangeValues dPrice = priceRange;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        // ← keeps sheet above home-indicator
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewPadding.bottom + 24, // 24px extra
            top: 24,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateDialog) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // ───────── Location ─────────
                  const Text('Location:'),
                  Material(
                    child: TypeAheadField<Map<String, dynamic>>(
                      controller: suburbController,
                      suggestionsCallback: (pattern) {
                        if (pattern.isEmpty) return [];
                        final matches = allSuburbs.where((item) {
                          final sub = item['Suburb'].toString().toLowerCase();
                          final pc = item['Postcode'].toString();
                          return sub.contains(pattern.toLowerCase()) ||
                              pc.contains(pattern);
                        }).toList()
                          ..sort((a, b) => a['Suburb']
                              .toString()
                              .compareTo(b['Suburb'].toString()));
                        return matches.take(10).toList();
                      },
                      itemBuilder: (_, s) =>
                          ListTile(title: Text(_formatSuburb(s))),
                      onSelected: (s) {
                        setStateDialog(() {
                          dSuburb = s;
                          dSubText = _formatSuburb(s);
                          suburbController.text = dSubText;
                        });
                      },
                      builder: (_, textCtrl, focusNode) {
                        if (suburbController.text.isNotEmpty &&
                            textCtrl.text.isEmpty) {
                          textCtrl.text = suburbController.text;
                        }
                        return TextField(
                          controller: textCtrl,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Location (Suburb or Postcode)',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                      emptyBuilder: (_) => const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No suburb found.')),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ───────── Training Method ─────────
                  const Text('Training Method:'),
                  Wrap(
                    spacing: 8,
                    children: ['Online', 'Face-to-Face'].map((m) {
                      final sel = dMethods.contains(m);
                      return FilterChip(
                        label: Text(m),
                        selected: sel,
                        onSelected: (v) => setStateDialog(
                            () => v ? dMethods.add(m) : dMethods.remove(m)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ───────── Specialties ─────────
                  const Text('Specialties:'),
                  Wrap(
                    spacing: 8,
                    children: categoryColors.keys.map((c) {
                      final sel = dCats.contains(c);
                      return FilterChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (v) => setStateDialog(
                            () => v ? dCats.add(c) : dCats.remove(c)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ───────── Distance ─────────
                  const Text('Distance (km):'),
                  DropdownButton<int>(
                    value: dDistance,
                    onChanged: (v) => setStateDialog(() => dDistance = v!),
                    items: [5, 10, 20, 50, 100]
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text('$d km')))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // ───────── Rating ─────────
                  const Text('Minimum Rating:'),
                  DropdownButton<double>(
                    value: dRating,
                    onChanged: (v) => setStateDialog(() => dRating = v!),
                    items: [0.0, 3.0, 4.0, 4.5, 5.0]
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r == 0 ? 'All' : '$r+')))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // ───────── Price ─────────
                  const Text('Price Range (\$/hr):'),
                  Wrap(
                    spacing: 8,
                    children: priceRangeOptions.map((opt) {
                      final range = opt['range'] as RangeValues;
                      final sel = dPrice == range;
                      return ChoiceChip(
                        label: Text(opt['label']),
                        selected: sel,
                        onSelected: (v) =>
                            v ? setStateDialog(() => dPrice = range) : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ───────── Buttons ─────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          clearFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedDistance = dDistance;
                            minRating = dRating;
                            selectedSuburbData = dSuburb;
                            selectedSuburbText = dSubText;
                            selectedTrainingMethods = List.from(dMethods);
                            selectedCategories = List.from(dCats);
                            maxDistance = dDistance.toDouble();
                            priceRange = dPrice;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
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
  }

  // ---------------------------------------------------------------------------
  //                     SEARCH & BOTTOM NAV HELPERS
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

  // Long-press block seller
  void _showTrainerOptions(BuildContext ctx, Map<String, dynamic> trainer) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.block),
          title: const Text('Block seller'),
          onTap: () async {
            Navigator.pop(ctx);
            await BlockService.instance.block(trainer['uid']);
            if (!mounted) return;
            setState(() => _blocked.add(trainer['uid']));
            ScaffoldMessenger.of(ctx)
                .showSnackBar(const SnackBar(content: Text('Seller blocked')));
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //                               BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Trainers not allowed in marketplace
    if (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text('Marketplace is only available to customers.',
                  style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            final guest = user == null || user.isAnonymous;
            if (guest) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SplashPage()));
            } else {
              final isTrainerRole = userRole == 'trainer' ||
                  userRole == 'personal trainer' ||
                  userRole == 'personaltrainer';
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => isTrainerRole
                      ? const TrainerHomePage(showProfileCompleteMessage: false)
                      : const ListingsPage(),
                ),
              );
            }
          },
        ),
        title: const Text('Find a Personal Trainer',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFA726),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => showFilterDialog()),
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearch(context)),
        ],
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async => _refreshBlocked(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_buildActiveFilterChips().isNotEmpty)
                Wrap(spacing: 8, children: _buildActiveFilterChips()),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (isTrainerPaymentsEnabled
                          ? FirebaseFirestore.instance
                              .collection('trainer_profiles')
                              .where('completed', isEqualTo: true)
                              .where('isActive', isEqualTo: true)
                          : FirebaseFirestore.instance
                              .collection('trainer_profiles')
                              .where('completed', isEqualTo: true))
                      .snapshots(),
                  builder: (_, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs
                        .map<Map<String, dynamic>>((d) {
                          final m = d.data() as Map<String, dynamic>;
                          m['uid'] = d.id;
                          return m;
                        })
                        .where((t) => !_blocked.contains(t['uid']))
                        .toList();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _allTrainers = docs);
                    });

                    final filtered = _filterTrainers(docs);
                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text(
                              'No trainers found. Try adjusting filters!',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)));
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.5,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final trainer = filtered[i];
                        return InkWell(
                          onTap: () {
                            final isTrainerRole = userRole == 'trainer' ||
                                userRole == 'personal trainer' ||
                                userRole == 'personaltrainer';
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
                          child: TrainerCard(
                            name:
                                trainer['name'] ?? trainer['displayName'] ?? '',
                            specialties:
                                List<String>.from(trainer['specialties'] ?? []),
                            location:
                                trainer['location'] ?? trainer['suburb'] ?? '',
                            categoryColors: categoryColors,
                            profileImageUrl: trainer['profileImageUrl'] ?? '',
                            trainerData: trainer,
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
      bottomNavigationBar: Container(
        color: Colors.black,
        child: _buildBottomNavigation(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//                         SEARCH DELEGATE
// ---------------------------------------------------------------------------
class TrainerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> trainers;
  final String userRole;
  TrainerSearchDelegate(this.trainers, this.userRole);

  @override
  List<Widget> buildActions(BuildContext _) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext ctx) {
    final results = trainers
        .where((t) => (t['name'] ?? t['displayName'] ?? '')
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    return _list(ctx, results);
  }

  @override
  Widget buildSuggestions(BuildContext ctx) {
    final sugg = trainers
        .where((t) => (t['name'] ?? t['displayName'] ?? '')
            .toString()
            .toLowerCase()
            .startsWith(query.toLowerCase()))
        .toList();
    return _list(ctx, sugg);
  }

  Widget _list(BuildContext ctx, List<Map<String, dynamic>> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final trainer = items[i];
        return ListTile(
          title: Text(trainer['name'] ?? trainer['displayName'] ?? ''),
          subtitle: Text(trainer['location'] ?? ''),
          onTap: () {
            final isTrainerRole = userRole == 'trainer' ||
                userRole == 'personal trainer' ||
                userRole == 'personaltrainer';
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
        );
      },
    );
  }
}
