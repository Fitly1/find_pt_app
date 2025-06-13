import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'secure_storage_service.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Basic listing fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedLocation;
  Map<String, dynamic>? _selectedSuburb; // lat/lng

  final List<String> _trainingMethods = ["Both", "Online", "Face-to-Face"];
  String _selectedTrainingMethod = "Both";

  List<Map<String, dynamic>> _suburbsData = [];

  final List<String> _allSpecialties = [
    "Strength Training",
    "Recovery",
    "Yoga",
    "Group Training",
    "Pilates",
    "Cardio",
    "HIIT",
    "Endurance",
    "Aerobics",
    "CrossFit",
    "Dance Fitness",
    "Martial Arts",
    "Weight Loss",
    "Pre/Post Pregnancy",
    "Other",
  ];
  final List<String> _selectedSpecialties = [];

  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadSuburbs();

    if (widget.isEditing && widget.existingData != null) {
      final data = widget.existingData!;
      _titleController.text = data["title"] ?? "";
      _descriptionController.text = data["description"] ?? "";
      _selectedLocation = data["location"] ?? "";
      if (data["trainingMethod"] != null) {
        _selectedTrainingMethod = data["trainingMethod"];
      }
      if (data["specialties"] is List) {
        _selectedSpecialties
            .addAll((data["specialties"] as List).map((e) => e.toString()));
      }
    }
  }

  // ────────────────────────── NEW: confirm-delete dialog ─────────────────────────
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content:
            const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog

              if (widget.listingId != null) {
                await FirebaseFirestore.instance
                    .collection('listings')
                    .doc(widget.listingId)
                    .update({'deleted': true});
              }

              if (!mounted) return;
              Navigator.pop(context); // exit CreateListingPage

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing deleted')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  // ───────────────────────────────────────────────────────────────────────────────

  /// Loads suburb data from assets/Suburbs.json.
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

  /// Submits the listing to Firestore.
  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one specialty.")),
      );
      return;
    }

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location.")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No user is logged in.")),
      );
      return;
    }

    final listingData = {
      "title": _titleController.text.trim(),
      "description": _descriptionController.text.trim(),
      "location": _selectedLocation,
      "trainingMethod": _selectedTrainingMethod,
      "specialties": _selectedSpecialties,
      "timestamp": FieldValue.serverTimestamp(),
      "userId": user.uid,
    };

    listingData["deleted"] = false;

    if (!widget.isEditing) {
      listingData["createdAt"] = FieldValue.serverTimestamp();
    }

    if (_selectedSuburb != null) {
      double lat =
          double.tryParse(_selectedSuburb!["Latitude"]?.toString() ?? "0") ??
              0.0;
      double lng =
          double.tryParse(_selectedSuburb!["Longitude"]?.toString() ?? "0") ??
              0.0;
      listingData["geoLocation"] = {"lat": lat, "lng": lng};
    }

    try {
      if (widget.isEditing && widget.listingId != null) {
        await FirebaseFirestore.instance
            .collection("listings")
            .doc(widget.listingId)
            .update(listingData);
      } else {
        await FirebaseFirestore.instance.collection("listings").add(listingData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Listing saved successfully!")),
      );
      Navigator.pop(context);

      await secureStorage.writeData(
        'last_listing_submission',
        DateTime.now().toIso8601String(),
      );

      String? submissionTimestamp =
          await secureStorage.readData('last_listing_submission');
      debugPrint("Last listing submission timestamp: $submissionTimestamp");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving listing: $e")),
      );
    }
  }

  /// Using the older TypeAheadField to pick location in a bottom sheet.
  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Search Location",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TypeAheadField<Map<String, dynamic>>(
                    suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) return [];
                      final matches = _suburbsData.where((item) {
                        final suburb =
                            item["Suburb"]?.toString().toLowerCase() ?? "";
                        final postcode = item["Postcode"]?.toString() ?? "";
                        return suburb.contains(pattern.toLowerCase()) ||
                            postcode.contains(pattern);
                      }).toList();
                      return matches.take(10).toList();
                    },
                    itemBuilder: (context, suggestion) {
                      final display =
                          "${suggestion['Suburb']}, ${suggestion['State']} (${suggestion['Postcode']})";
                      return ListTile(title: Text(display));
                    },
                    onSelected: (suggestion) {
                      setState(() {
                        _selectedLocation =
                            "${suggestion['Suburb']}, ${suggestion['State']} (${suggestion['Postcode']})";
                        _selectedSuburb = suggestion;
                      });
                      Navigator.pop(context);
                    },
                    builder: (context, suggestionsController, focusNode) {
                      return TextField(
                        controller: suggestionsController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: "e.g., 2147 or Seven Hills",
                          border: OutlineInputBorder(),
                          helperText:
                              "This helps match you with nearby trainers",
                        ),
                      );
                    },
                    emptyBuilder: (context) => const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No matching suburb/postcode found."),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? "Edit Listing" : "Create Listing"),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------- Basic Information -------------
              const Text(
                "Basic Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "What are your training goals?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _titleController,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? "This field is required"
                        : null,
                decoration: const InputDecoration(
                  hintText: "e.g., I need help with weight loss",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Description:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _descriptionController,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? "Description is required"
                        : null,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Provide details about your training needs...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ------------- Location -------------
              const Text(
                "Location (Suburb/Postcode):",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLocationBottomSheet,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _selectedLocation == null || _selectedLocation!.isEmpty
                        ? "Select Location"
                        : _selectedLocation!,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 167, 38),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ------------- Preferences -------------
              const Text(
                "Preferences",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "Preferred Training Method:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedTrainingMethod,
                items: _trainingMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTrainingMethod = value!;
                  });
                },
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? "Preferred training method is required"
                        : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Specialties:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _allSpecialties.map((specialty) {
                  final isSelected = _selectedSpecialties.contains(specialty);
                  return FilterChip(
                    label: Text(specialty),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSpecialties.add(specialty);
                        } else {
                          _selectedSpecialties.remove(specialty);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ------------- Submit Button -------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 167, 38),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.isEditing ? "Save Changes" : "Create Listing",
                  ),
                ),
              ),

              // ────────────────────── NEW: Delete Button ──────────────────────
              if (widget.isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _confirmDelete(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Delete Listing',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              // ────────────────────────────────────────────────────────────────
            ],
          ),
        ),
      ),
    );
  }
}