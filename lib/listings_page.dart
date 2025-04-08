import 'dart:convert';
import 'dart:math'; // For mathematical functions
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:intl/intl.dart'; // For DateFormat
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
import 'create_listing_page.dart'; // Page for customers to create/edit listings
import 'listing_detail_page.dart'; // Page to view listing details
import 'bottom_navigation_customers.dart'; // Customer bottom nav
import 'marketplace_page.dart'; // For returning via the back arrow
import 'bottom_navigation.dart'; // Trainer bottom nav
import 'trainer_home_page.dart';

import 'package:flutter_typeahead/flutter_typeahead.dart'; // Using flutter_typeahead (older API as in Marketplace page)

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key});

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  // Color coding for specialties.
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

  // Filter state variables.
  String _trainingMethodFilter = "all";
  String _suburbFilter =
      "all"; // e.g. "Mount Stromlo, Australian Capital Territory (2611)"
  // Use a dedicated controller for the suburb field (like in Marketplace page)
  final TextEditingController suburbController = TextEditingController();

  // Other filter variables
  int selectedDistance = 50;
  double maxDistance = 50.0;
  double minRating = 0.0;

  // For storing the chosen suburb data (with lat/lng).
  Map<String, dynamic>? selectedSuburbData;
  // For displaying the chosen suburb text (formatted).
  String selectedSuburbText = '';

  // Other filtering criteria can be added here (if needed)

  // For role-based navigation.
  String userRole = 'customer'; // Default role

  // For suburb data
  List<Map<String, dynamic>> _suburbsData = [];
  final List<String> _trainingMethods = ["all", "online", "face-to-face"];

  @override
  void initState() {
    super.initState();
    _loadSuburbs();
    suburbController.text = (_suburbFilter == "all") ? "" : _suburbFilter;
    _loadUserRole();
  }

  /// Helper: Formats a suburb map into full details.
  /// E.g.: "Mount Stromlo, Australian Capital Territory (2611)"
  String _formatSuburb(Map<String, dynamic> item) {
    return "${item['Suburb']}, ${item['State']} (${item['Postcode']})";
  }

  Future<void> _loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'customer';
    });
    debugPrint("ListingsPage: Loaded user role: $userRole");
  }

  Future<void> _loadSuburbs() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
      setState(() {
        _suburbsData =
            jsonData.map((item) => item as Map<String, dynamic>).toList();
      });
      debugPrint("✅ Loaded ${_suburbsData.length} suburbs from JSON.");
    } catch (e) {
      debugPrint("❌ Error loading suburbs data: $e");
    }
  }

  // Haversine formula to calculate distance.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Builds a Firestore query.
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('listings');
    if (_trainingMethodFilter != "all") {
      debugPrint("🔍 Filtering by method: $_trainingMethodFilter");
      query = query.where("trainingMethodPreference",
          arrayContains: _trainingMethodFilter);
    }
    if (_suburbFilter != "all" && selectedSuburbData == null) {
      debugPrint("🔍 Filtering by suburb (exact match): $_suburbFilter");
      query = query.where("location", isEqualTo: _suburbFilter);
    }
    query = query.orderBy('timestamp', descending: true);
    return query;
  }

  /// Applies distance-based filtering locally if we have selectedSuburbData.
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
          debugPrint(
              "Listing distance: $distance km vs maxDistance: $maxDistance");
          return distance <= maxDistance;
        }
        return false;
      }).toList();
    }
    return listings;
  }

  /// Builds active filter chips.
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
          onDeleted: () {
            setState(() {
              _trainingMethodFilter = "all";
            });
          },
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
    return Wrap(spacing: 8.0, children: chips);
  }

  /// Clears all filters.
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

  /// Opens the bottom sheet for filtering.
  /// This version follows the Marketplace page exactly.
  void _openFilterSheet() {
    // Local variables for the dialog.
    String localMethod = _trainingMethodFilter;
    int localDistance = selectedDistance;
    // Use the same suburbController as in the Marketplace page.
    final TextEditingController localSuburbController = suburbController;
    // Local variables to hold the chosen suburb data and formatted text.
    Map<String, dynamic>? dialogSelectedSuburbData = selectedSuburbData;
    String dialogSelectedSuburbText = selectedSuburbText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator:
          true, // Ensures the suggestions overlay renders properly.
      builder: (BuildContext ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Training Method Section
                      const Text(
                        'Training Method:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: _trainingMethods.map((method) {
                          return RadioListTile<String>(
                            title: Text(method),
                            value: method,
                            groupValue: localMethod,
                            onChanged: (value) {
                              setStateDialog(() {
                                localMethod = value!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Suburb Section (copied exactly from Marketplace)
                      const Text(
                        'Suburb:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        child: TypeAheadField<Map<String, dynamic>>(
                          controller: localSuburbController,
                          suggestionsCallback: (pattern) async {
                            if (pattern.isEmpty) return [];
                            Iterable<Map<String, dynamic>> matches =
                                _suburbsData.where((item) {
                              String suburb =
                                  item['Suburb']?.toString().toLowerCase() ??
                                      '';
                              String postcode =
                                  item['Postcode']?.toString() ?? '';
                              return suburb.contains(pattern.toLowerCase()) ||
                                  postcode.contains(pattern);
                            });
                            List<Map<String, dynamic>> suggestions =
                                matches.toList();
                            suggestions.sort((a, b) => a['Suburb']
                                .toString()
                                .compareTo(b['Suburb'].toString()));
                            return suggestions.take(10).toList();
                          },
                          itemBuilder: (context, suggestion) {
                            String display = _formatSuburb(suggestion);
                            return ListTile(title: Text(display));
                          },
                          onSelected: (suggestion) {
                            setStateDialog(() {
                              dialogSelectedSuburbData = suggestion;
                              dialogSelectedSuburbText =
                                  _formatSuburb(suggestion);
                              localSuburbController.text =
                                  dialogSelectedSuburbText;
                            });
                          },
                          builder: (context, suggestionsController, focusNode) {
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
                          emptyBuilder: (context) => const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("No suburb found."),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Distance Section
                      const Text(
                        'Distance (km):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<int>(
                        value: localDistance,
                        onChanged: (value) {
                          setStateDialog(() {
                            localDistance = value!;
                          });
                        },
                        items: [5, 10, 20, 50, 100].map((distance) {
                          return DropdownMenuItem<int>(
                            value: distance,
                            child: Text('$distance km'),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      // Action Buttons
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
                              debugPrint(
                                  "Applied suburb filter: $_suburbFilter");
                              debugPrint(
                                  "Applied distance filter: $maxDistance km");
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
        );
      },
    );
  }

  /// Returns the appropriate bottom navigation widget based on the user's role.
  Widget _buildBottomNavigation() {
    bool isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');
    return isTrainer
        ? const BottomNavigation(currentIndex: 2)
        : const BottomNavigationCustomers(currentIndex: 2);
  }

  @override
  Widget build(BuildContext context) {
    final query = _buildQuery();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          },
        ),
        title: const Text(
          "Find a Personal Trainer",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildActiveFilterChips(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("StreamBuilder error: ${snapshot.error}");
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  debugPrint("No data yet.");
                  return const Center(child: CircularProgressIndicator());
                }
                final rawListings = snapshot.data!.docs.map((doc) {
                  return {
                    ...doc.data() as Map<String, dynamic>,
                    "uid": doc.id,
                  };
                }).toList();
                final listings = (selectedSuburbData != null)
                    ? _applyLocalFilters(rawListings)
                    : rawListings;
                if (listings.isEmpty) {
                  return const Center(child: Text("No listings available."));
                }
                return ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final data = listings[index];
                    final title = data["title"] ?? "No title";
                    final description = data["description"] ?? "";
                    final location = data["location"] ?? "";
                    final Timestamp? ts = data["timestamp"];
                    final formattedTime = ts != null
                        ? DateFormat('dd MMM yyyy').format(ts.toDate())
                        : "Unknown time";
                    final List<dynamic> specialties = data["specialties"] ?? [];
                    final specialtyChips = specialties.map((s) {
                      final specialty = s.toString();
                      final color = categoryColors[specialty] ?? Colors.grey;
                      return Chip(
                        label: Text(specialty),
                        backgroundColor: color,
                        labelStyle: const TextStyle(color: Colors.white),
                      );
                    }).toList();
                    final String creatorName = data["firstName"] ?? "Unknown";
                    final String profileImageUrl =
                        data["profileImageUrl"] ?? "";
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage: profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl)
                              : const AssetImage('assets/default_profile.png')
                                  as ImageProvider,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text("By: $creatorName",
                                style: const TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(description),
                            const SizedBox(height: 4),
                            Text("Location: $location"),
                            if (specialtyChips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  children: specialtyChips),
                            ],
                          ],
                        ),
                        trailing: Text(formattedTime),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListingDetailPage(
                                listingData: data,
                                listingId: data["uid"],
                              ),
                            ),
                          );
                        },
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
            backgroundColor: const Color.fromARGB(255, 255, 167, 38),
            tooltip: "Create a Listing",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateListingPage()),
              );
            },
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
}

class TrainerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> trainers;
  final String userRole; // Passed from MarketplacePage
  TrainerSearchDelegate(this.trainers, this.userRole);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          })
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          close(context, null);
        });
  }

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
      itemBuilder: (context, index) {
        final trainer = results[index];
        return ListTile(
          title: Text(trainer['name'] ?? trainer['displayName'] ?? ''),
          subtitle: Text(trainer['location'] ?? ''),
          onTap: () {
            bool isTrainerRole = (userRole == 'trainer' ||
                userRole == 'personal trainer' ||
                userRole == 'personaltrainer');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerHomePage(
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
      itemBuilder: (context, index) {
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
