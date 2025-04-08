// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // For using Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http; // For downloading the image
import 'crop_page.dart'; // Adjust path if in a subfolder

// Import your secure storage service
import 'secure_storage_service.dart';

/// Predefined specialties with their corresponding colors.
const Map<String, Color> specialtiesMap = {
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

/// Brand color (#FFA726).
const kBrandOrange = Color(0xFFFFA726);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Controllers for various fields.
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Store selected suburb details.
  Map<String, dynamic>? _selectedSuburb;

  // Image and work images.
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final List<File> _workImages = [];

  // Saved work image URLs.
  List<String> _savedWorkImageUrls = [];
  String _existingImageUrl = "";

  // Multi-select specialties.
  List<String> _selectedSpecialties = [];
  late final List<MultiSelectItem<String>> _specialtiesItems = specialtiesMap
      .keys
      .map((specialty) => MultiSelectItem<String>(specialty, specialty))
      .toList();

  // Suburbs data loaded from JSON.
  List<Map<String, dynamic>> _suburbs = [];

  // Training methods.
  List<String> _selectedMethods = [];

  // For showing progress.
  bool _isSaving = false;

  // Experience state: numeric value and unit ("Years" or "Months").
  int? _experienceValue;
  String? _experienceUnit;

  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(() => setState(() {}));
    _lastNameController.addListener(() => setState(() {}));
    _experienceValue = 1;
    _experienceUnit = "Years";
    _loadProfileData();
    _loadSuburbs();
  }

  // Helper function to capitalize a name.
  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Future<void> _loadSuburbs() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Suburbs.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _suburbs =
            jsonData.map((item) => item as Map<String, dynamic>).toList();
      });
      debugPrint("✅ Loaded ${_suburbs.length} suburbs (EditProfile).");
    } catch (e) {
      debugPrint("❌ Error loading suburbs data: $e");
    }
  }

  Future<void> _loadProfileData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _emailController.text = user.email ?? "";
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _firstNameController.text = data["firstName"] ?? "";
        _lastNameController.text = data["lastName"] ?? "";
        _descriptionController.text = data['description'] ?? '';
        _selectedSpecialties = (data['specialties'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toList() ??
            [];
        _mobileController.text = data['mobile'] ?? '';
        _locationController.text = data['location'] ?? "";
        if (data['experience'] != null) {
          final expString = data['experience'].toString().toLowerCase();
          if (expString.contains("month")) {
            _experienceUnit = "Months";
            final number =
                int.tryParse(expString.replaceAll(RegExp(r'[^0-9]'), ""));
            _experienceValue = number ?? 0;
          } else if (expString.contains("year")) {
            _experienceUnit = "Years";
            final number =
                int.tryParse(expString.replaceAll(RegExp(r'[^0-9]'), ""));
            _experienceValue = number ?? 0;
          } else {
            _experienceValue = int.tryParse(data['experience'].toString()) ?? 0;
            _experienceUnit = "Years";
          }
        }
        _rateController.text = data['rate']?.toString() ?? "";
        _selectedMethods = (data['trainingMethods'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toList() ??
            [];
        _existingImageUrl = data['profileImageUrl'] ?? "";
        _savedWorkImageUrls = (data['workImageUrls'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toList() ??
            [];
      });
    }
  }

  Future<String> _uploadProfileImage() async {
    if (_profileImage == null) return "";
    try {
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("trainer_images")
          .child("${FirebaseAuth.instance.currentUser!.uid}.jpg");
      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      await uploadTask.whenComplete(() => null);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading profile image: $e");
      return "";
    }
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(tempDir.path,
        "${path.basenameWithoutExtension(file.path)}_compressed${path.extension(file.path)}");
    var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, targetPath,
        quality: 80);
    if (result == null) return null;
    return File(result.path);
  }

  Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint("Error downloading image: $e");
    }
    return null;
  }

  /// Helper function to crop and compress an image.
  Future<File?> _cropAndCompressImage(File imageFile) async {
    // Use the new CropPage which accepts an imagePath.
    final Uint8List? croppedData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CropPage(imagePath: imageFile.path)),
    );
    if (croppedData == null) return null;
    final tempDir = await getTemporaryDirectory();
    final croppedFilePath = path.join(tempDir.path,
        "cropped_image_${DateTime.now().millisecondsSinceEpoch}.jpg");
    final croppedFile = await File(croppedFilePath).writeAsBytes(croppedData);
    final File? compressedFile = await _compressImage(croppedFile);
    return compressedFile;
  }

  // Pick a new profile image by navigating to CropPage.
  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final File rawFile = File(pickedFile.path);
    final File? processedFile = await _cropAndCompressImage(rawFile);
    if (processedFile == null) return;
    final bytes = await processedFile.length();
    if (bytes > 500 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Profile image exceeds 500KB limit even after compression.")));
    } else {
      setState(() {
        _profileImage = processedFile;
      });
    }
  }

  // Re-crop an existing image by navigating to CropPage.
  Future<void> _reCropExistingImage() async {
    if (_existingImageUrl.isEmpty) return;
    final imageBytes = await _downloadImage(_existingImageUrl);
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download existing image.")));
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final filePath = path.join(tempDir.path, "existing_image.jpg");
    final imageFile = await File(filePath).writeAsBytes(imageBytes);
    final File? processedFile = await _cropAndCompressImage(imageFile);
    if (processedFile == null) return;
    final bytes = await processedFile.length();
    if (bytes > 500 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Image exceeds 500KB limit even after compression.")));
    } else {
      setState(() {
        _profileImage = processedFile;
      });
    }
  }

  // Pick a new work image.
  Future<void> _pickWorkImage() async {
    if (_workImages.length + _savedWorkImageUrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maximum of 6 work images allowed.")));
      return;
    }
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      File? compressedFile = await _compressImage(file);
      if (compressedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image compression failed.")));
        return;
      }
      final bytes = await compressedFile.length();
      if (bytes > 500 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Work image exceeds 500KB limit even after compression.")));
      } else {
        setState(() {
          _workImages.add(compressedFile);
          debugPrint(
              "Added work image. Total new work images: ${_workImages.length}");
        });
      }
    }
  }

  void _removeWorkImage(int index) {
    setState(() {
      if (index < _savedWorkImageUrls.length) {
        _savedWorkImageUrls.removeAt(index);
      } else {
        int fileIndex = index - _savedWorkImageUrls.length;
        _workImages.removeAt(fileIndex);
      }
      debugPrint(
          "Removed work image. Total saved: ${_savedWorkImageUrls.length}, new: ${_workImages.length}");
    });
  }

  List<dynamic> get _combinedWorkImages {
    return [..._savedWorkImageUrls, ..._workImages];
  }

  Future<List<String>> _uploadWorkImages() async {
    List<String> workImageUrls = [];
    debugPrint("Starting upload of ${_workImages.length} new work images.");
    for (File image in _workImages) {
      try {
        final String fileName =
            "${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        debugPrint("Uploading work image: $fileName");
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child("trainer_work_images")
            .child(fileName);
        final UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask.whenComplete(() => null);
        String url = await storageRef.getDownloadURL();
        workImageUrls.add(url);
        debugPrint("Uploaded work image URL: $url");
      } catch (e) {
        debugPrint("Error uploading work image: $e");
      }
    }
    debugPrint("Finished uploading new work images. URLs: $workImageUrls");
    return workImageUrls;
  }

  void _afterSaveProfile(bool isActive) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile saved successfully!")),
    );
    if (!isActive) {
      _showActivationPrompt();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("First Name is required.")));
      return;
    }
    if (_lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Last Name is required.")));
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Description is required.")));
      return;
    }
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select at least one Specialty.")));
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Location is required.")));
      return;
    }
    if (_rateController.text.trim().isEmpty ||
        (double.tryParse(_rateController.text.trim()) ?? 0.0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Rate is required and must be greater than 0.")));
      return;
    }
    if ((_profileImage == null) && (_existingImageUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile image is required.")));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String finalImageUrl =
        _profileImage != null ? await _uploadProfileImage() : _existingImageUrl;
    final List<String> newWorkImageUrls = await _uploadWorkImages();
    debugPrint("New work image URLs: $newWorkImageUrls");
    final List<String> finalWorkImageUrls = [
      ..._savedWorkImageUrls,
      ...newWorkImageUrls
    ];
    debugPrint("Final work image URLs to save: $finalWorkImageUrls");

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    // Capitalize first and last names using the helper function.
    final String formattedFirstName = capitalize(firstName);
    final String formattedLastName = capitalize(lastName);
    final String combinedName = "$formattedFirstName $formattedLastName".trim();
    final String experienceString =
        "${_experienceValue ?? 0} ${_experienceUnit ?? 'Years'}";

    final profileData = {
      "firstName": formattedFirstName,
      "firstName_lowerCase": formattedFirstName.toLowerCase(),
      "lastName": formattedLastName,
      "lastName_lowerCase": formattedLastName.toLowerCase(),
      "displayName": combinedName,
      "displayName_lowerCase": combinedName.toLowerCase(),
      "description": _descriptionController.text.trim(),
      "specialties": _selectedSpecialties,
      "mobile": _mobileController.text.trim(),
      "location": _locationController.text.trim(),
      "experience": experienceString,
      "rate": double.tryParse(_rateController.text.trim()) ?? 0.0,
      "profileImageUrl": finalImageUrl,
      "workImageUrls": finalWorkImageUrls,
      "trainingMethods": _selectedMethods,
      "completed": true,
    };

    if (_selectedSuburb != null) {
      double lat =
          double.tryParse(_selectedSuburb!['Latitude'].toString()) ?? 0.0;
      double lng =
          double.tryParse(_selectedSuburb!['Longitude'].toString()) ?? 0.0;
      if (lat != 0.0 || lng != 0.0) {
        profileData["geoLocation"] = {"lat": lat, "lng": lng};
      }
    }

    await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .set(profileData, SetOptions(merge: true));

    // <-- Security integration: Save last profile update timestamp securely.
    await secureStorage.writeData(
      'last_profile_update',
      DateTime.now().toIso8601String(),
    );
    // Retrieve and print the timestamp from secure storage for debugging.
    String? updateTimestamp =
        await secureStorage.readData('last_profile_update');
    debugPrint("Last profile update timestamp: $updateTimestamp");

    debugPrint("Saved profile for UID: ${user.uid}");
    debugPrint("FirstName: $formattedFirstName, LastName: $formattedLastName");

    final doc = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .get();
    bool isActive = (doc.data() as Map<String, dynamic>)["isActive"] ?? false;

    setState(() {
      _isSaving = false;
    });

    _afterSaveProfile(isActive);
  }

  void _showActivationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Activate Membership"),
          content: const Text(
              "Your profile details have been saved, but your membership is inactive. Would you like to activate it now?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("Maybe Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _activateSubscription();
              },
              child: const Text("Activate Now"),
            ),
          ],
        );
      },
    );
  }

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx2, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Search Location",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(height: 16),
                  TypeAheadField<Map<String, dynamic>>(
                    suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) return [];
                      final matches = _suburbs.where((item) {
                        final suburb =
                            item["Suburb"]?.toString().toLowerCase() ?? '';
                        final postcode = item["Postcode"]?.toString() ?? '';
                        return suburb.contains(pattern.toLowerCase()) ||
                            postcode.contains(pattern);
                      }).toList();
                      return matches.take(10).toList();
                    },
                    itemBuilder: (context, suggestion) {
                      final display =
                          "${suggestion['Suburb']}, ${suggestion['State']} (${suggestion['Postcode']})";
                      return ListTile(
                        title:
                            Text(display, style: const TextStyle(fontSize: 16)),
                      );
                    },
                    onSelected: (suggestion) {
                      setState(() {
                        _locationController.text =
                            "${suggestion['Suburb']}, ${suggestion['State']} (${suggestion['Postcode']})";
                        _selectedSuburb = suggestion;
                      });
                      Navigator.pop(context);
                    },
                    builder: (context, suggestionsController, focusNode) {
                      return TextField(
                        controller: suggestionsController,
                        focusNode: focusNode,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: "e.g., 2147 or Seven Hills",
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 16),
                          border: OutlineInputBorder(),
                          helperText:
                              "This helps match you with nearby trainers",
                        ),
                      );
                    },
                    emptyBuilder: (context) => const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("No matching suburb/postcode found.",
                          style: TextStyle(fontSize: 16, color: Colors.black)),
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

  InputDecoration _commonTextFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 18, color: Colors.black),
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _activateSubscription() async {
    final ctx = context;
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text("Loading...")));
      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result = await callable.call();
      if (!mounted) return;
      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text("Failed to get checkout URL.")));
        return;
      }
      if (await canLaunchUrl(Uri.parse(sessionUrl))) {
        await launchUrl(Uri.parse(sessionUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $sessionUrl';
      }
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text("Error starting subscription: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveName =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: kBrandOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : _existingImageUrl.isNotEmpty
                                ? NetworkImage(_existingImageUrl)
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickProfileImage,
                      ),
                    ],
                  ),
                  if (_existingImageUrl.isNotEmpty)
                    TextButton(
                      onPressed: _reCropExistingImage,
                      child: const Icon(Icons.crop, color: kBrandOrange),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Live display of name
            Text(
              liveName.isEmpty ? "No Name" : liveName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // First Name
            TextField(
              controller: _firstNameController,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: _commonTextFieldDecoration("First Name"),
            ),
            const SizedBox(height: 16),
            // Last Name
            TextField(
              controller: _lastNameController,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: _commonTextFieldDecoration("Last Name"),
            ),
            const SizedBox(height: 16),
            // Read-only Email Field
            TextField(
              controller: _emailController,
              readOnly: true,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              decoration: _commonTextFieldDecoration("Email Address"),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: _commonTextFieldDecoration(
                  "Profile Description, Expertise and Certification"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Multi-select Specialties
            MultiSelectDialogField(
              items: _specialtiesItems,
              title: const Text("Specialties",
                  style: TextStyle(fontSize: 18, color: Colors.black)),
              buttonText: const Text("Select Specialties",
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              buttonIcon: const Icon(Icons.fitness_center, color: Colors.black),
              initialValue: _selectedSpecialties,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              searchable: true,
              listType: MultiSelectListType.CHIP,
              onConfirm: (values) {
                setState(() {
                  _selectedSpecialties = List<String>.from(values);
                });
              },
            ),
            const SizedBox(height: 16),
            // Mobile Number
            TextField(
              controller: _mobileController,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                labelStyle: TextStyle(fontSize: 18, color: Colors.black),
                hintText: "Enter your mobile number",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // Location Field (modal bottom sheet)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Your Location:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showLocationBottomSheet,
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(
                  _locationController.text.isEmpty
                      ? "Select Location"
                      : _locationController.text,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange),
              ),
            ),
            const SizedBox(height: 16),
            // Experience widget with integrated dropdown and toggle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text("Experience:", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _experienceValue,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      items: List.generate(51, (index) => index)
                          .map((int value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              ))
                          .toList(),
                      onChanged: (int? newValue) {
                        setState(() {
                          _experienceValue = newValue;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [
                      _experienceUnit == "Years",
                      _experienceUnit == "Months"
                    ],
                    onPressed: (int index) {
                      setState(() {
                        _experienceUnit = index == 0 ? "Years" : "Months";
                      });
                    },
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("Years")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("Months")),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Rate
            TextField(
              controller: _rateController,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              decoration: _commonTextFieldDecoration("Rate (\$/hr)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // Training Methods
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kBrandOrange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Training Method:",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kBrandOrange)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: const Text("Online"),
                        selected: _selectedMethods.contains("Online"),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMethods.add("Online");
                            } else {
                              _selectedMethods.remove("Online");
                            }
                          });
                        },
                        selectedColor: kBrandOrange,
                        checkmarkColor: const Color.fromARGB(255, 1, 0, 0),
                        labelStyle: TextStyle(
                            color: _selectedMethods.contains("Online")
                                ? Colors.white
                                : Colors.black),
                      ),
                      FilterChip(
                        label: const Text("Face-to-Face"),
                        selected: _selectedMethods.contains("Face-to-Face"),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMethods.add("Face-to-Face");
                            } else {
                              _selectedMethods.remove("Face-to-Face");
                            }
                          });
                        },
                        selectedColor: kBrandOrange,
                        checkmarkColor: const Color.fromARGB(255, 0, 0, 0),
                        labelStyle: TextStyle(
                            color: _selectedMethods.contains("Face-to-Face")
                                ? Colors.white
                                : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Work Images
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Work Images (max 6, 500KB each)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _combinedWorkImages.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemBuilder: (context, index) {
                if (index < _combinedWorkImages.length) {
                  final item = _combinedWorkImages[index];
                  ImageProvider imageProvider;
                  if (item is String) {
                    imageProvider = NetworkImage(item);
                  } else if (item is File) {
                    imageProvider = FileImage(item);
                  } else {
                    imageProvider =
                        const AssetImage('assets/default_profile.png');
                  }
                  return Stack(
                    children: [
                      Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _removeWorkImage(index),
                        ),
                      )
                    ],
                  );
                } else {
                  return GestureDetector(
                    onTap: _pickWorkImage,
                    child: Container(
                      color: const Color.fromARGB(255, 254, 254, 254),
                      child: const Icon(Icons.add),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            // Save Button or Progress Indicator
            _isSaving
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Save Profile",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
