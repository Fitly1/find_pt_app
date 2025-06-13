import 'package:flutter/material.dart';
import 'dart:convert'; // For decoding JSON
import 'dart:math'; // For mathematical functions
import 'package:flutter/services.dart'; // For loading assets
import 'package:flutter_typeahead/flutter_typeahead.dart'; // For typeahead suggestions
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:firebase_core/firebase_core.dart'; // For checking Firebase initialization
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth
import 'package:shared_preferences/shared_preferences.dart'; // For SharedPreferences
import 'bottom_navigation.dart'; // Shared trainer bottom navigation
import 'bottom_navigation_customers.dart'; // Customer-specific bottom navigation

import 'components/trainer_card.dart';
import 'trainer_home_page.dart';
import 'welcome_page.dart';
import 'listings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Find PT App',
      debugShowCheckedModeBanner: false,
      home: MarketplacePage(),
    );
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.lightBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MarketplacePage()),
            );
          },
        ),
      ),
      body: const Center(child: Text('Profile Page Content')),
    );
  }
}

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});
  @override
  MarketplacePageState createState() => MarketplacePageState();
}

class MarketplacePageState extends State<MarketplacePage> {
  // Filtering variables:
  List<Map<String, dynamic>> allSuburbs = [];
  Map<String, dynamic>? selectedSuburbData;
  String selectedSuburbText = '';

  // Price range now defaults to $20 - $150,
  // but is changed ONLY via choice chips (no slider).
  RangeValues priceRange = const RangeValues(20, 150);

  double maxDistance = 1000.0; // in kilometers
  int selectedDistance = 50; // default distance option
  double minRating = 0.0; // default minimum rating

  // Clearly labeled default price range options (no slider).
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

  // Additional filtering criteria.
  List<String> selectedCategories = [];
  List<String> selectedTrainingMethods = [];
  List<String> selectedPriceRanges = [];

  // State variable to store the current list of trainers.
  List<Map<String, dynamic>> _allTrainers = [];

  // Controller for the location field in the filter UI.
  final TextEditingController suburbController = TextEditingController();

  // User role stored locally (default is customer)
  String userRole = 'customer';

  @override
  void initState() {
    super.initState();
    loadSuburbData();
    loadUserRole();
  }

  /// Loads the user role from SharedPreferences.
  Future<void> loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'customer';
    });
    debugPrint("MarketplacePage: Loaded user role: $userRole");
  }

  /// Loads suburb data from assets/Suburbs.json.
  Future<void> loadSuburbData() async {
    try {
      final String jsonData =
          await rootBundle.loadString('assets/Suburbs.json');
      allSuburbs = (json.decode(jsonData) as List).cast<Map<String, dynamic>>();
      debugPrint('Loaded ${allSuburbs.length} suburbs.');
      setState(() {});
    } catch (e) {
      debugPrint("Error loading suburbs data: $e");
    }
  }

  /// Formats a suburb map into a display string.
  String _formatSuburb(Map<String, dynamic> item) {
    return "${item['Suburb']}, ${item['State']} (${item['Postcode']})";
  }

  /// Calculates distance in km between two lat/lng pairs (Haversine formula).
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Filters trainers based on the selected filters.
  List<Map<String, dynamic>> _filterTrainers(
      List<Map<String, dynamic>> trainersList) {
    return trainersList.where((trainer) {
      // Specialties filter (case-insensitive).
      bool matchesCategory = selectedCategories.isEmpty ||
          selectedCategories.any((category) {
            String selected = category.toLowerCase();
            List<dynamic> specialties = trainer['specialties'] ?? [];
            return specialties
                .map((e) => e.toString().toLowerCase())
                .contains(selected);
          });

      // Rating filter.
      double trainerRating = ((trainer['rating'] as num?)?.toDouble() ?? 0.0);
      bool matchesRating = trainerRating >= minRating;

      // Price filter.
      bool matchesPrice = true;
      if (trainer['rate'] != null && trainer['rate'] is num) {
        double rate = (trainer['rate'] as num).toDouble();
        matchesPrice = (rate >= priceRange.start && rate <= priceRange.end);
      } else {
        matchesPrice = false;
      }

      // Suburb filter and distance filter.
      bool matchesSuburb = true;
      bool matchesDistance = true;
      if (selectedSuburbData != null) {
        double userLat =
            double.tryParse(selectedSuburbData!['Latitude'].toString()) ?? 0.0;
        double userLng =
            double.tryParse(selectedSuburbData!['Longitude'].toString()) ?? 0.0;
        final geoLocation = trainer['geoLocation'];
        if (geoLocation is Map) {
          double trainerLat = (geoLocation['lat'] as num?)?.toDouble() ?? 0.0;
          double trainerLng = (geoLocation['lng'] as num?)?.toDouble() ?? 0.0;
          double distanceKm =
              calculateDistance(trainerLat, trainerLng, userLat, userLng);
          matchesDistance = distanceKm <= maxDistance;
          debugPrint(
            "Trainer: ${trainer['displayName'] ?? trainer['name']} distance: $distanceKm km => within $maxDistance? $matchesDistance",
          );
        } else {
          matchesDistance = false;
        }
      }

      // Training method filter.
      bool matchesTrainingMethod = selectedTrainingMethods.isEmpty ||
          selectedTrainingMethods.contains(trainer['method']) ||
          (trainer['trainingMethods'] is List &&
              (trainer['trainingMethods'] as List)
                  .any((m) => selectedTrainingMethods.contains(m)));

      return matchesCategory &&
          matchesRating &&
          matchesPrice &&
          matchesSuburb &&
          matchesTrainingMethod &&
          matchesDistance;
    }).toList();
  }

  void clearFilters() {
    setState(() {
      selectedCategories.clear();
      selectedTrainingMethods.clear();
      selectedPriceRanges.clear();
      selectedSuburbData = null;
      selectedSuburbText = '';
      selectedDistance = 50;
      minRating = 0.0;
      maxDistance = 1000.0;
      // Reset the price range to $20 - $150.
      priceRange = const RangeValues(20, 150);
    });
  }

  /// Builds active filter chips to display at the top of the page.
  List<Widget> _buildActiveFilterChips() {
    List<Widget> chips = [];
    if (selectedSuburbText.isNotEmpty) {
      chips.add(
        Chip(
          label: Text("Suburb: $selectedSuburbText"),
          onDeleted: () {
            setState(() {
              selectedSuburbData = null;
              selectedSuburbText = '';
            });
          },
        ),
      );
    }
    if (selectedTrainingMethods.isNotEmpty) {
      chips.add(
        Chip(
          label: Text("Training: ${selectedTrainingMethods.join(', ')}"),
          onDeleted: () {
            setState(() {
              selectedTrainingMethods.clear();
            });
          },
        ),
      );
    }
    if (selectedCategories.isNotEmpty) {
      chips.add(
        Chip(
          label: Text("Specialties: ${selectedCategories.join(', ')}"),
          onDeleted: () {
            setState(() {
              selectedCategories.clear();
            });
          },
        ),
      );
    }
    if (minRating > 0.0) {
      chips.add(
        Chip(
          label: Text("Min Rating: ${minRating.toStringAsFixed(1)}+"),
          onDeleted: () {
            setState(() {
              minRating = 0.0;
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
    if (priceRange.start != 20 || priceRange.end != 150) {
      chips.add(
        Chip(
          label: Text(
              "Price: \$${priceRange.start.toInt()}-\$${priceRange.end.toInt()}"),
          onDeleted: () {
            setState(() {
              priceRange = const RangeValues(20, 150);
            });
          },
        ),
      );
    }
    return chips;
  }

  // Show filter UI as a modal bottom sheet.
  void showFilterDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || !user.emailVerified) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            title: const Text(
              "Sign Up",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Please create an account or sign in to access features.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WelcomePage()),
                  );
                },
                child: const Text(
                  "OK",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          );
        },
      );
      return;
    }
    // Local copies of existing filter states.
    int dialogSelectedDistance = selectedDistance;
    double dialogSelectedRating = minRating;
    Map<String, dynamic>? dialogSelectedSuburbData = selectedSuburbData;
    String dialogSelectedSuburbText = selectedSuburbText;
    List<String> dialogSelectedTrainingMethods =
        List.from(selectedTrainingMethods);
    List<String> dialogSelectedCategories = List.from(selectedCategories);
    RangeValues dialogPriceRange = priceRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filters',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('Location:'),
                      Material(
                        child: TypeAheadField<Map<String, dynamic>>(
                          controller: suburbController,
                          suggestionsCallback: (pattern) async {
                            if (pattern.isEmpty) return [];
                            Iterable<Map<String, dynamic>> matches =
                                allSuburbs.where((item) {
                              String suburb =
                                  item['Suburb'].toString().toLowerCase();
                              String postcode = item['Postcode'].toString();
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
                              suburbController.text = dialogSelectedSuburbText;
                            });
                          },
                          builder: (context, suggestionsController, focusNode) {
                            if (suburbController.text.isNotEmpty &&
                                suggestionsController.text.isEmpty) {
                              suggestionsController.text =
                                  suburbController.text;
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
                      const Text('Training Method:'),
                      Wrap(
                        spacing: 8.0,
                        children: ['Online', 'Face-to-Face'].map((method) {
                          bool isSelected =
                              dialogSelectedTrainingMethods.contains(method);
                          return FilterChip(
                            label: Text(method),
                            selected: isSelected,
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) {
                                  dialogSelectedTrainingMethods.add(method);
                                } else {
                                  dialogSelectedTrainingMethods.remove(method);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Specialties:'),
                      Wrap(
                        spacing: 8.0,
                        children: categoryColors.keys.map((category) {
                          bool isSelected =
                              dialogSelectedCategories.contains(category);
                          return FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) {
                                  dialogSelectedCategories.add(category);
                                } else {
                                  dialogSelectedCategories.remove(category);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Distance (km):'),
                      DropdownButton<int>(
                        value: dialogSelectedDistance,
                        onChanged: (value) {
                          setStateDialog(() {
                            dialogSelectedDistance = value!;
                          });
                        },
                        items: [5, 10, 20, 50, 100].map((distance) {
                          return DropdownMenuItem<int>(
                            value: distance,
                            child: Text('$distance km'),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Minimum Rating:'),
                      DropdownButton<double>(
                        value: dialogSelectedRating,
                        onChanged: (value) {
                          setStateDialog(() {
                            dialogSelectedRating = value!;
                          });
                        },
                        items: [0.0, 3.0, 4.0, 4.5, 5.0].map((rating) {
                          return DropdownMenuItem<double>(
                            value: rating,
                            child: Text(rating == 0.0 ? "All" : '$rating+'),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Price Range (\$/hr):'),
                      // Only use choice chips for price range.
                      Wrap(
                        spacing: 8.0,
                        children: priceRangeOptions.map((option) {
                          final RangeValues thisRange = option['range'];
                          final bool isSelected =
                              (dialogPriceRange == thisRange);
                          return ChoiceChip(
                            label: Text(option['label']),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setStateDialog(() {
                                  dialogPriceRange = thisRange;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              clearFilters();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear Filters'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedDistance = dialogSelectedDistance;
                                minRating = dialogSelectedRating;
                                selectedSuburbData = dialogSelectedSuburbData;
                                selectedSuburbText = dialogSelectedSuburbText;
                                selectedTrainingMethods =
                                    List.from(dialogSelectedTrainingMethods);
                                selectedCategories =
                                    List.from(dialogSelectedCategories);
                                maxDistance = dialogSelectedDistance.toDouble();
                                // Apply the chosen price range from choice chips.
                                priceRange = dialogPriceRange;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply'),
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

  // Show search UI with a guest check.
  void _showSearch(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || !user.emailVerified) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Sign In Required"),
          content: const Text(
              "Please sign in or sign up to manage your subscription."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              },
              child: const Text("Sign In / Sign Up"),
            ),
          ],
        ),
      );
      return;
    }
    // Pass the updated _allTrainers list to the search delegate.
    showSearch(
      context: context,
      delegate: TrainerSearchDelegate(_allTrainers, userRole),
    );
  }

  /// Returns the appropriate bottom navigation widget based on the user's role.
  Widget _buildBottomNavigation() {
    bool isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');
    return isTrainer
        ? const BottomNavigation(currentIndex: 0)
        : const BottomNavigationCustomers(currentIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      // AppBar now uses the orange brand color with white text/icons.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            debugPrint("=== Back arrow tapped ===");
            if (user == null) {
              debugPrint("No user is signed in.");
            } else {
              debugPrint("UID: ${user.uid}");
              debugPrint("isAnonymous: ${user.isAnonymous}");
              debugPrint("emailVerified: ${user.emailVerified}");
            }
            bool isGuest = (user == null || user.isAnonymous);
            if (isGuest) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WelcomePage()),
              );
            } else {
              bool isTrainer = (userRole == 'trainer' ||
                  userRole == 'personal trainer' ||
                  userRole == 'personaltrainer');
              if (isTrainer) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerHomePage(
                      showProfileCompleteMessage: false,
                    ),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ListingsPage()),
                );
              }
            }
          },
        ),
        title: const Text(
          "Find a Personal Trainer",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFFA726), // Orange app bar
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.isAnonymous || !user.emailVerified) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      title: const Text(
                        "Sign Up",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        "Please create an account or sign in to access features.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const WelcomePage()),
                            );
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    );
                  },
                );
                return;
              }
              showFilterDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      backgroundColor: Colors.white, // White overall background
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // The content remains largely the same.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_buildActiveFilterChips().isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: _buildActiveFilterChips(),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("trainer_profiles")
                    .where("completed", isEqualTo: true)
                    .where("isActive", isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint("StreamBuilder error: ${snapshot.error}");
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData) {
                    debugPrint("No data yet.");
                    return const Center(child: CircularProgressIndicator());
                  }
                  final localTrainers = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data["uid"] = doc.id; // Ensure the UID is added
                    return data;
                  }).toList();

                  // Update _allTrainers so the search delegate has the latest data.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _allTrainers = localTrainers;
                      });
                    }
                  });

                  final filtered = _filterTrainers(localTrainers);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        "No trainers found. Try adjusting filters!",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                      childAspectRatio: 0.5,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final trainer = filtered[index];
                      return InkWell(
                        onTap: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          debugPrint("=== Trainer card tapped ===");
                          if (user == null) {
                            debugPrint("No user is signed in.");
                          } else {
                            debugPrint("UID: ${user.uid}");
                            debugPrint("isAnonymous: ${user.isAnonymous}");
                            debugPrint("emailVerified: ${user.emailVerified}");
                          }
                          if (user == null ||
                              user.isAnonymous ||
                              !user.emailVerified) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                  title: const Text(
                                    "Sign Up",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  content: const Text(
                                    "Please create an account or sign in to access features.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  actionsAlignment: MainAxisAlignment.center,
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const WelcomePage()),
                                        );
                                      },
                                      child: const Text(
                                        "OK",
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }
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
                        child: TrainerCard(
                          name: trainer['name'] ?? trainer['displayName'] ?? '',
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
