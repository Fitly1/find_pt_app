import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:flutter_typeahead/flutter_typeahead.dart';

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key});

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  /* -------------------------------------------------------------------------- */
  /*                               STATE VARIABLES                              */
  /* -------------------------------------------------------------------------- */

  // Category colours
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

  // Filters
  String _trainingMethodFilter = "all";
  String _suburbFilter = "all";
  final TextEditingController suburbController = TextEditingController();
  int selectedDistance = 50;
  double maxDistance = 50.0;
  double minRating = 0.0;

  Map<String, dynamic>? selectedSuburbData;
  String selectedSuburbText = '';

  // Role handling
  String userRole = 'customer';
  bool _roleChecked = false; // shows loader until true

  // Suburb data
  List<Map<String, dynamic>> _suburbsData = [];
  final List<String> _trainingMethods = ["all", "online", "face-to-face"];

  /* -------------------------------------------------------------------------- */
  /*                               INITIALISATION                               */
  /* -------------------------------------------------------------------------- */

  @override
  void initState() {
    super.initState();
    _loadSuburbs();
    suburbController.text = (_suburbFilter == "all") ? "" : _suburbFilter;
    _loadUserRole(); // loads but NO redirect
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString("userRole")?.toLowerCase() ?? 'customer';

    if (mounted) {
      setState(() {
        userRole = role;
        _roleChecked = true; // allow UI to render
      });
    }
    debugPrint("ListingsPage: role loaded = $role");
  }

  /* -------------------------------------------------------------------------- */
  /*                         BACK-NAVIGATION HELPER                              */
  /* -------------------------------------------------------------------------- */

  void _handleBack() {
    final isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isTrainer ? const TrainerHomePage() : const MarketplacePage(),
      ),
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                          OTHER HELPERS / LOADERS                           */
  /* -------------------------------------------------------------------------- */

  Future<void> _loadSuburbs() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
      setState(() => _suburbsData = jsonData.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint("❌ Error loading suburbs data: $e");
    }
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

  /* -------------------------------------------------------------------------- */
  /*                              FIRESTORE QUERY                               */
  /* -------------------------------------------------------------------------- */

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('listings')
        .where('deleted', isEqualTo: false);

    if (_trainingMethodFilter != "all") {
      query = query.where("trainingMethodPreference",
          arrayContains: _trainingMethodFilter);
    }

    if (_suburbFilter != "all" && selectedSuburbData == null) {
      query = query.where("location", isEqualTo: _suburbFilter);
    }

    return query.orderBy('timestamp', descending: true);
  }

  List<Map<String, dynamic>> _applyLocalFilters(
      List<Map<String, dynamic>> listings) {
    if (selectedSuburbData != null) {
      listings = listings.where((listing) {
        final geo = listing['geoLocation'];
        if (geo is Map) {
          double trainerLat = (geo['lat'] as num?)?.toDouble() ?? 0.0;
          double trainerLng = (geo['lng'] as num?)?.toDouble() ?? 0.0;
          double userLat =
              double.tryParse(selectedSuburbData!['Latitude'].toString()) ??
                  0.0;
          double userLng =
              double.tryParse(selectedSuburbData!['Longitude'].toString()) ??
                  0.0;
          double distance =
              calculateDistance(trainerLat, trainerLng, userLat, userLng);
          return distance <= maxDistance;
        }
        return false;
      }).toList();
    }
    return listings;
  }

  /* -------------------------------------------------------------------------- */
  /*                                UI HELPERS                                  */
  /* -------------------------------------------------------------------------- */

  Widget _buildActiveFilterChips() {
    List<Widget> chips = [];
    if (selectedSuburbText.isNotEmpty) {
      chips.add(
        Chip(
          label: Text("Suburb: $selectedSuburbText"),
          onDeleted: () {
            setState(() {
              selectedSuburbData = null;
              selectedSuburbText = '';
              _suburbFilter = "all";
              suburbController.text = "";
            });
          },
        ),
      );
    }
    if (_trainingMethodFilter != "all") {
      chips.add(
        Chip(
          label: Text("Training: $_trainingMethodFilter"),
          onDeleted: () => setState(() => _trainingMethodFilter = "all"),
        ),
      );
    }
    if (selectedDistance != 50) {
      chips.add(
        Chip(
          label: Text("Distance: $selectedDistance km"),
          onDeleted: () {
            setState(() {
              selectedDistance = 50;
              maxDistance = 50.0;
            });
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(spacing: 8.0, runSpacing: 4.0, children: chips),
    );
  }

  void clearFilters() {
    setState(() {
      _trainingMethodFilter = "all";
      _suburbFilter = "all";
      selectedSuburbData = null;
      selectedSuburbText = "";
      selectedDistance = 50;
      maxDistance = 50.0;
      minRating = 0.0;
      suburbController.clear();
    });
  }

  /* ---------------------------------------------------------------------- */
  /*                         FILTER BOTTOM-SHEET UI                         */
  /* ---------------------------------------------------------------------- */

  void _openFilterSheet() {
    String localMethod = _trainingMethodFilter;
    int localDistance = selectedDistance;
    final TextEditingController localSuburbController = suburbController;
    Map<String, dynamic>? dialogSelectedSuburbData = selectedSuburbData;
    String dialogSelectedSuburbText = selectedSuburbText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateDialog) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Filters',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Training method
                        const Text('Training Method:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        RadioGroup<String>(
                          groupValue: localMethod,
                          onChanged: (value) =>
                              setStateDialog(() => localMethod = value!),
                          child: Column(
                            children: _trainingMethods
                                .map((method) => RadioListTile<String>(
                                      title: Text(method),
                                      value: method,
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Suburb
                        const Text('Suburb:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Material(
                          child: TypeAheadField<Map<String, dynamic>>(
                            controller: localSuburbController,
                            suggestionsCallback: (pattern) async {
                              if (pattern.isEmpty) return [];
                              final lower = pattern.toLowerCase();
                              return _suburbsData
                                  .where((item) {
                                    final suburb = item['Suburb']
                                            ?.toString()
                                            .toLowerCase() ??
                                        '';
                                    final postcode =
                                        item['Postcode']?.toString() ?? '';
                                    return suburb.contains(lower) ||
                                        postcode.contains(pattern);
                                  })
                                  .take(10)
                                  .toList();
                            },
                            itemBuilder: (_, suggestion) => ListTile(
                                title: Text(_formatSuburb(suggestion))),
                            onSelected: (suggestion) {
                              setStateDialog(() {
                                dialogSelectedSuburbData = suggestion;
                                dialogSelectedSuburbText =
                                    _formatSuburb(suggestion);
                                localSuburbController.text =
                                    dialogSelectedSuburbText;
                              });
                            },
                            builder: (_, suggestionsController, focusNode) {
                              if (localSuburbController.text.isNotEmpty &&
                                  suggestionsController.text.isEmpty) {
                                suggestionsController.text =
                                    localSuburbController.text;
                              }
                              return TextField(
                                controller: suggestionsController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: "Location (Suburb or Postcode)",
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                            emptyBuilder: (_) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("No suburb found."),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Distance
                        const Text('Distance (km):',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<int>(
                          value: localDistance,
                          onChanged: (val) =>
                              setStateDialog(() => localDistance = val!),
                          items: [5, 10, 20, 50, 100]
                              .map((d) => DropdownMenuItem(
                                  value: d, child: Text('$d km')))
                              .toList(),
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                setStateDialog(() {
                                  localSuburbController.clear();
                                  dialogSelectedSuburbData = null;
                                  dialogSelectedSuburbText = '';
                                });
                              },
                              child: const Text("Clear Suburb"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _trainingMethodFilter = localMethod;
                                  _suburbFilter =
                                      localSuburbController.text.isEmpty
                                          ? "all"
                                          : dialogSelectedSuburbText;
                                  selectedDistance = localDistance;
                                  maxDistance = localDistance.toDouble();
                                  selectedSuburbText = dialogSelectedSuburbText;
                                  selectedSuburbData = dialogSelectedSuburbData;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text("Apply Filters"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    final isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');
    return isTrainer
        ? const BottomNavigation(currentIndex: 2)
        : const BottomNavigationCustomers(currentIndex: 2);
  }

  /* -------------------------------------------------------------------------- */
  /*                                  BUILD                                     */
  /* -------------------------------------------------------------------------- */

  @override
  Widget build(BuildContext context) {
    if (!_roleChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final query = _buildQuery();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBack, // role-aware
        ),
        title: const Text("Listings", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFA726),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _openFilterSheet,
            tooltip: 'Filters',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildActiveFilterChips(),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawListings = snapshot.data!.docs
                    .map((doc) =>
                        {...doc.data() as Map<String, dynamic>, "uid": doc.id})
                    .toList();

                final listings = (selectedSuburbData != null)
                    ? _applyLocalFilters(rawListings)
                    : rawListings;

                if (listings.isEmpty) {
                  return const Center(child: Text("No listings available."));
                }

                return ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, index) {
                    final data = listings[index];
                    final rawTitle = (data["title"] ?? "No title").toString();
                    final title = _capitalize(rawTitle);
                    final description = (data["description"] ?? "").toString();
                    final location = (data["location"] ?? "").toString();
                    final Timestamp? ts = data["timestamp"];
                    final formattedTime = ts != null
                        ? DateFormat('dd MMM yyyy').format(ts.toDate())
                        : "Unknown time";
                    final List<dynamic> specialties = data["specialties"] ?? [];
                    final specialtyChips = specialties.map((s) {
                      final spec = s.toString();
                      final color = categoryColors[spec] ?? Colors.grey;
                      return Chip(
                        label: Text(spec),
                        backgroundColor: color,
                        labelStyle: const TextStyle(color: Colors.white),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 0),
                      );
                    }).toList();
                    final String creatorName =
                        (data["firstName"] ?? "Unknown").toString();
                    final String profileImageUrl =
                        (data["profileImageUrl"] ?? "").toString();

                    // Redesigned card
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListingDetailPage(
                              listingData: data,
                              listingId: data["uid"],
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: avatar + title + meta
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : const AssetImage(
                                                'assets/default_profile.png')
                                            as ImageProvider,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "By $creatorName • $formattedTime",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Description
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.3),
                                ),

                              const SizedBox(height: 10),

                              // Location row
                              if (location.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),

                              // Specialties chips
                              if (specialtyChips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  children: specialtyChips,
                                ),
                              ],
                            ],
                          ),
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
      floatingActionButton: Builder(
        builder: (ctx) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null ||
              user.isAnonymous ||
              !user.emailVerified ||
              userRole != 'customer') {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            backgroundColor: const Color(0xFFFFA726),
            tooltip: "Create a Listing",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateListingPage()),
            ),
            child: const Icon(Icons.add),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        child: _buildBottomNavigation(),
      ),
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                                 UTILITIES                                  */
  /* -------------------------------------------------------------------------- */

  String _formatSuburb(Map<String, dynamic> item) =>
      "${item['Suburb']}, ${item['State']} (${item['Postcode']})";

  // Capitalize FIRST character only (as requested).
  String _capitalize(String text) {
    final t = text.trimLeft();
    if (t.isEmpty) return text;
    final leadingSpaceCount = text.length - t.length;
    final leadingSpaces =
        leadingSpaceCount > 0 ? text.substring(0, leadingSpaceCount) : '';
    return leadingSpaces + t[0].toUpperCase() + t.substring(1);
  }
}

/* -------------------------------------------------------------------------- */
/*                       SEARCH DELEGATE  (unchanged)                         */
/* -------------------------------------------------------------------------- */

class TrainerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> trainers;
  final String userRole;

  TrainerSearchDelegate(this.trainers, this.userRole);

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    final results = trainers.where((trainer) {
      return (trainer['name']
              ?.toString()
              .toLowerCase()
              .contains(query.toLowerCase()) ??
          false);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, index) {
        final trainer = results[index];
        return ListTile(
          title: Text(trainer['name'] ?? trainer['displayName'] ?? ''),
          subtitle: Text(trainer['location'] ?? ''),
          onTap: () {
            final isTrainerRole = (userRole == 'trainer' ||
                userRole == 'personal trainer' ||
                userRole == 'personaltrainer');
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
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = trainers.where((trainer) {
      return (trainer['name']
              ?.toString()
              .toLowerCase()
              .startsWith(query.toLowerCase()) ??
          false);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, index) {
        final trainer = suggestions[index];
        return ListTile(
          title: Text(trainer['name'] ?? trainer['displayName'] ?? ''),
          onTap: () {
            query = trainer['name'] ?? trainer['displayName'] ?? '';
            showResults(context);
          },
        );
      },
    );
  }
}
