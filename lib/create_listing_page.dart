import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  /* ─────────────────────────  controllers / keys ───────────────────────── */
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  /* ─────────────────────────────  data fields ──────────────────────────── */
  String? _selectedLocation;
  Map<String, dynamic>? _selectedSuburb; // lat / lng

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

  /* ───────────────────────────── lifecycle ─────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _loadSuburbs();

    if (widget.isEditing && widget.existingData != null) {
      final data = widget.existingData!;
      _titleController.text = data["title"] ?? "";
      _descriptionController.text = data["description"] ?? "";
      _selectedLocation = data["location"] ?? "";
      _selectedTrainingMethod =
          data["trainingMethod"] ?? _selectedTrainingMethod;
      if (data["specialties"] is List) {
        _selectedSpecialties
            .addAll((data["specialties"] as List).map((e) => e.toString()));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /* ─────────────────────────── suburb loading ──────────────────────────── */
  Future<void> _loadSuburbs() async {
    try {
      final jsonString = await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
      setState(() {
        _suburbsData = jsonData.map((e) => e as Map<String, dynamic>).toList();
      });
      debugPrint("✅ Loaded ${_suburbsData.length} suburbs from JSON.");
    } catch (e) {
      debugPrint("❌ Error loading suburbs data: $e");
    }
  }

  /* ─────────────────────────────  submit  ──────────────────────────────── */
  Future<void> _submitListing() async {
    // Grab navigator / messenger up-front to avoid using context after await.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpecialties.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Please select at least one specialty.")));
      return;
    }
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Please select a location.")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Error: No user is logged in.")));
      return;
    }

    final listingData = <String, dynamic>{
      "title": _titleController.text.trim(),
      "description": _descriptionController.text.trim(),
      "location": _selectedLocation,
      "trainingMethod": _selectedTrainingMethod,
      "specialties": _selectedSpecialties,
      "timestamp": FieldValue.serverTimestamp(),
      "userId": user.uid,
      "deleted": false,
    };

    if (!widget.isEditing) {
      listingData["createdAt"] = FieldValue.serverTimestamp();
    }

    if (_selectedSuburb != null) {
      listingData["geoLocation"] = {
        "lat": double.tryParse(_selectedSuburb!["Latitude"].toString()) ?? 0.0,
        "lng": double.tryParse(_selectedSuburb!["Longitude"].toString()) ?? 0.0,
      };
    }

    try {
      if (widget.isEditing && widget.listingId != null) {
        await FirebaseFirestore.instance
            .collection("listings")
            .doc(widget.listingId)
            .update(listingData);
      } else {
        await FirebaseFirestore.instance
            .collection("listings")
            .add(listingData);
      }

      messenger.showSnackBar(
          const SnackBar(content: Text("Listing saved successfully!")));
      navigator.pop();

      // Store timestamp (no UI needed).
      await secureStorage.writeData(
          'last_listing_submission', DateTime.now().toIso8601String());
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text("Error saving listing: $e")));
    }
  }

  /* ────────────────────────── delete listing ───────────────────────────── */
  void _confirmDelete(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(parentContext);
              final navigator = Navigator.of(parentContext);

              Navigator.pop(dialogContext); // close dialog

              if (widget.listingId != null) {
                await FirebaseFirestore.instance
                    .collection('listings')
                    .doc(widget.listingId)
                    .update({'deleted': true});
              }

              if (!mounted) return;
              navigator.pop(); // leave page
              messenger.showSnackBar(
                  const SnackBar(content: Text('Listing deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /* ───────────────────── location picker bottom-sheet ──────────────────── */
  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("Search Location",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TypeAheadField<Map<String, dynamic>>(
                    // ←--- original working async callback kept intact
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
                    itemBuilder: (ctx, suggestion) {
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
                      Navigator.pop(ctx);
                    },
                    builder: (ctx, textController, focusNode) {
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: "e.g., 2147 or Seven Hills",
                          border: OutlineInputBorder(),
                          helperText:
                              "This helps match you with nearby trainers",
                        ),
                      );
                    },
                    emptyBuilder: (ctx) => const Padding(
                      padding: EdgeInsets.all(8),
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

  /* ─────────────────────────────  UI  ──────────────────────────────────── */
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
              /* ────────────── Basic information ────────────── */
              const Text("Basic Information",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              const Text("What are your training goals?",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _titleController,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
                decoration: const InputDecoration(
                  hintText: "e.g., I need help with weight loss",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Description:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _descriptionController,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Provide details about your training needs...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              /* ────────────── Location ────────────── */
              const Text("Location (Suburb/Postcode):",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLocationBottomSheet,
                  icon: const Icon(Icons.search),
                  label: Text(_selectedLocation?.isEmpty ?? true
                      ? "Select Location"
                      : _selectedLocation!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 167, 38),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              /* ────────────── Preferences ────────────── */
              const Text("Preferences",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              const Text("Preferred Training Method:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedTrainingMethod,
                onChanged: (v) => setState(() => _selectedTrainingMethod = v!),
                items: _trainingMethods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text("Specialties:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allSpecialties.map((s) {
                  final selected = _selectedSpecialties.contains(s);
                  return FilterChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (sel) => setState(() {
                      sel
                          ? _selectedSpecialties.add(s)
                          : _selectedSpecialties.remove(s);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              /* ────────────── Submit / Delete ────────────── */
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 167, 38),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                      widget.isEditing ? "Save Changes" : "Create Listing"),
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirmDelete(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete Listing',
                        style: TextStyle(color: Colors.white)),
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
