// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:http/http.dart' as http;

import 'crop_page.dart';
import 'secure_storage_service.dart';
import 'feature_flags.dart';

const kBrandOrange = Color(0xFFFFA726);

/// Flat list of specialties (we don't actually use the colors anywhere)
const List<String> kSpecialties = [
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

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Suburbs / geo
  Map<String, dynamic>? _selectedSuburb;
  List<Map<String, dynamic>> _suburbs = [];

  // Images
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final List<File> _workImages = [];
  List<String> _savedWorkImageUrls = [];
  String _existingImageUrl = "";

  // Specialties
  late final List<MultiSelectItem<String>> _specialtiesItems =
      kSpecialties.map((s) => MultiSelectItem<String>(s, s)).toList();
  List<String> _selectedSpecialties = [];

  // Training methods
  List<String> _selectedMethods = [];

  // Experience
  int? _experienceValue;
  String? _experienceUnit;

  // State
  bool _isSaving = false;

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

  // ───────────────────── Helpers ─────────────────────

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 14),
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      isDense: true,
      filled: readOnly,
      enabled: !readOnly,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ───────────────────── Data Loading ─────────────────────

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

    final doc = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    if (!mounted) return;
    setState(() {
      _firstNameController.text = data["firstName"] ?? "";
      _lastNameController.text = data["lastName"] ?? "";
      _descriptionController.text = data['description'] ?? '';
      _selectedSpecialties = (data['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      _mobileController.text = data['mobile'] ?? '';
      _locationController.text = data['location'] ?? "";

      // Parse "3 Years" / "6 Months" / etc
      if (data['experience'] != null) {
        final expString = data['experience'].toString().toLowerCase();
        final numericPart =
            int.tryParse(expString.replaceAll(RegExp(r'[^0-9]'), ""));
        if (expString.contains("month")) {
          _experienceUnit = "Months";
          _experienceValue = numericPart ?? 0;
        } else if (expString.contains("year")) {
          _experienceUnit = "Years";
          _experienceValue = numericPart ?? 0;
        } else {
          _experienceValue = int.tryParse(data['experience'].toString()) ?? 0;
          _experienceUnit = "Years";
        }
      }

      _rateController.text = data['rate']?.toString() ?? "";
      _selectedMethods = (data['trainingMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      _existingImageUrl = data['profileImageUrl'] ?? "";
      _savedWorkImageUrls = (data['workImageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    });
  }

  // ───────────────────── Image Handling ─────────────────────

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(
      tempDir.path,
      "${path.basenameWithoutExtension(file.path)}_compressed${path.extension(file.path)}",
    );
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
    );
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

  Future<File?> _cropAndCompressImage(File imageFile) async {
    final Uint8List? croppedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropPage(imagePath: imageFile.path),
      ),
    );
    if (croppedData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final croppedFilePath = path.join(
      tempDir.path,
      "cropped_image_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
    final croppedFile = await File(croppedFilePath).writeAsBytes(croppedData);
    return _compressImage(croppedFile);
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final File rawFile = File(pickedFile.path);
    final File? processedFile = await _cropAndCompressImage(rawFile);
    if (processedFile == null) return;

    final bytes = await processedFile.length();
    if (bytes > 500 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("Profile image exceeds 500KB limit even after compression."),
      ));
      return;
    }

    setState(() {
      _profileImage = processedFile;
    });
  }

  Future<void> _reCropExistingImage() async {
    if (_existingImageUrl.isEmpty) return;

    final imageBytes = await _downloadImage(_existingImageUrl);
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to download existing image.")),
      );
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
        content: Text("Image exceeds 500KB limit even after compression."),
      ));
      return;
    }

    setState(() {
      _profileImage = processedFile;
    });
  }

  Future<String> _uploadProfileImage() async {
    if (_profileImage == null) return "";
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("trainer_images")
          .child("${user.uid}.jpg");
      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      await uploadTask.whenComplete(() => null);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading profile image: $e");
      return "";
    }
  }

  Future<void> _pickWorkImage() async {
    if (_workImages.length + _savedWorkImageUrls.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum of 6 work images allowed.")),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final compressedFile = await _compressImage(file);
    if (compressedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image compression failed.")),
      );
      return;
    }

    final bytes = await compressedFile.length();
    if (bytes > 500 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Work image exceeds 500KB limit even after compression."),
      ));
      return;
    }

    setState(() {
      _workImages.add(compressedFile);
    });
  }

  void _removeWorkImage(int index) {
    setState(() {
      if (index < _savedWorkImageUrls.length) {
        _savedWorkImageUrls.removeAt(index);
      } else {
        final fileIndex = index - _savedWorkImageUrls.length;
        _workImages.removeAt(fileIndex);
      }
    });
  }

  List<dynamic> get _combinedWorkImages =>
      [..._savedWorkImageUrls, ..._workImages];

  Future<List<String>> _uploadWorkImages() async {
    final List<String> workImageUrls = [];
    final user = FirebaseAuth.instance.currentUser!;
    for (final image in _workImages) {
      try {
        final String fileName =
            "${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child("trainer_work_images")
            .child(fileName);
        final UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask.whenComplete(() => null);
        final url = await storageRef.getDownloadURL();
        workImageUrls.add(url);
      } catch (e) {
        debugPrint("Error uploading work image: $e");
      }
    }
    return workImageUrls;
  }

  // ───────────────────── Location / Suburb Bottom Sheet ─────────────────────

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx2, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const Text(
                    "Search Location",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        style: const TextStyle(fontSize: 16),
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
                      child: Text(
                        "No matching suburb/postcode found.",
                        style: TextStyle(fontSize: 16),
                      ),
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

  // ───────────────────── Save Logic / Subscription ─────────────────────

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

  void _showActivationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Activate Membership"),
          content: const Text(
            "Your profile details have been saved, but your membership is inactive. Would you like to activate it now?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
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

  Future<void> _activateSubscription() async {
    final ctx = context;
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text("Loading...")),
      );
      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result = await callable.call();
      if (!mounted) return;
      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Failed to get checkout URL.")),
        );
        return;
      }
      final uri = Uri.parse(sessionUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $sessionUrl';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text("Error starting subscription: $e")),
      );
    }
  }

  Future<void> _saveProfile() async {
    // Same validation rules as your original file
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("First Name is required.")),
      );
      return;
    }
    if (_lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Last Name is required.")),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Description is required.")),
      );
      return;
    }
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one Specialty.")),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location is required.")),
      );
      return;
    }
    if (_rateController.text.trim().isEmpty ||
        (double.tryParse(_rateController.text.trim()) ?? 0.0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rate is required and must be greater than 0."),
        ),
      );
      return;
    }
    if ((_profileImage == null) && (_existingImageUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile image is required.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String finalImageUrl =
        _profileImage != null ? await _uploadProfileImage() : _existingImageUrl;

    final List<String> newWorkImageUrls = await _uploadWorkImages();
    final List<String> finalWorkImageUrls = [
      ..._savedWorkImageUrls,
      ...newWorkImageUrls,
    ];

    final formattedFirstName = _capitalise(_firstNameController.text.trim());
    final formattedLastName = _capitalise(_lastNameController.text.trim());
    final combinedName = "$formattedFirstName $formattedLastName".trim();
    final experienceString =
        "${_experienceValue ?? 0} ${_experienceUnit ?? 'Years'}";

    final profileData = <String, dynamic>{
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
      final lat =
          double.tryParse(_selectedSuburb!['Latitude'].toString()) ?? 0.0;
      final lng =
          double.tryParse(_selectedSuburb!['Longitude'].toString()) ?? 0.0;
      if (lat != 0.0 || lng != 0.0) {
        profileData["geoLocation"] = {"lat": lat, "lng": lng};
      }
    }

    await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .set(profileData, SetOptions(merge: true));

    await secureStorage.writeData(
      'last_profile_update',
      DateTime.now().toIso8601String(),
    );

    final doc = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .get();
    var isActive = (doc.data() as Map<String, dynamic>)["isActive"] ?? false;
    if (!isTrainerPaymentsEnabled) isActive = true;

    setState(() => _isSaving = false);
    _afterSaveProfile(isActive);
  }

  // ───────────────────── UI Sections ─────────────────────

  Widget _buildProfileHeader() {
    final liveName =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();

    final ImageProvider avatarProvider;
    if (_profileImage != null) {
      avatarProvider = FileImage(_profileImage!);
    } else if (_existingImageUrl.isNotEmpty) {
      avatarProvider = NetworkImage(_existingImageUrl);
    } else {
      avatarProvider = const AssetImage('assets/default_profile.png');
    }

    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: avatarProvider,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: InkWell(
                      onTap: _pickProfileImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: kBrandOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_existingImageUrl.isNotEmpty) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _reCropExistingImage,
                  icon: const Icon(Icons.crop, color: kBrandOrange),
                  label: const Text(
                    "Re-crop existing",
                    style: TextStyle(color: kBrandOrange),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          liveName.isEmpty ? "No Name" : liveName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicDetails() {
    return Column(
      children: [
        TextField(
          controller: _firstNameController,
          decoration: _fieldDecoration("First Name"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          decoration: _fieldDecoration("Last Name"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          readOnly: true,
          decoration: _fieldDecoration("Email Address", readOnly: true),
        ),
      ],
    );
  }

  Widget _buildBio() {
    return TextField(
      controller: _descriptionController,
      maxLength: 1000,
      maxLines: 4,
      decoration: _fieldDecoration(
        "Profile Description, Expertise and Certification",
        hint:
            "Tell customers who you work with, your style, and any key certs.",
      ),
    );
  }

  Widget _buildSpecialties() {
    return MultiSelectDialogField<String>(
      items: _specialtiesItems,
      title: const Text("Specialties", style: TextStyle(fontSize: 16)),
      buttonText: const Text(
        "Select Specialties",
        style: TextStyle(fontSize: 14),
      ),
      buttonIcon: const Icon(Icons.fitness_center),
      initialValue: _selectedSpecialties,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      searchable: true,
      listType: MultiSelectListType.CHIP,
      onConfirm: (values) {
        setState(() {
          _selectedSpecialties = List<String>.from(values);
        });
      },
    );
  }

  Widget _buildContactAndLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _mobileController,
          decoration: _fieldDecoration(
            "Mobile Number",
            hint: "Enter your mobile number",
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        const Text(
          "Your Location",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrandOrange,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceAndRate() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              "Experience:",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue:
                    _experienceValue, // <- use initialValue, not value
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                items: List.generate(51, (index) => index)
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _experienceValue = val),
              ),
            ),
            const SizedBox(width: 8),
            ToggleButtons(
              isSelected: [
                _experienceUnit == "Years",
                _experienceUnit == "Months"
              ],
              borderRadius: BorderRadius.circular(12),
              constraints: const BoxConstraints(minHeight: 34),
              onPressed: (index) {
                setState(() {
                  _experienceUnit = index == 0 ? "Years" : "Months";
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Years"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Months"),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rateController,
          decoration: _fieldDecoration("Rate (\$/hr)"),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildTrainingMethods() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: kBrandOrange, width: 1.4),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Training Method",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kBrandOrange,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
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
                labelStyle: TextStyle(
                  color: _selectedMethods.contains("Online")
                      ? Colors.white
                      : Colors.black,
                ),
                checkmarkColor: Colors.black,
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
                labelStyle: TextStyle(
                  color: _selectedMethods.contains("Face-to-Face")
                      ? Colors.white
                      : Colors.black,
                ),
                checkmarkColor: Colors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Work Images (max 6, 500KB each)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _combinedWorkImages.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < _combinedWorkImages.length) {
              final item = _combinedWorkImages[index];
              late final ImageProvider imageProvider;

              if (item is String) {
                imageProvider = NetworkImage(item);
              } else if (item is File) {
                imageProvider = FileImage(item);
              } else {
                imageProvider = const AssetImage('assets/default_profile.png');
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _removeWorkImage(index),
                    ),
                  ),
                ],
              );
            } else {
              return GestureDetector(
                onTap: _pickWorkImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Center(
                    child: Icon(Icons.add),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  // ───────────────────── Build ─────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: kBrandOrange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              _sectionCard(
                title: "Profile",
                subtitle: "This is the first thing customers see on your card.",
                child: _buildProfileHeader(),
              ),
              _sectionCard(
                title: "Basic details",
                child: _buildBasicDetails(),
              ),
              _sectionCard(
                title: "About you",
                subtitle:
                    "Share your background, coaching style, and certifications.",
                child: _buildBio(),
              ),
              _sectionCard(
                title: "Specialties",
                subtitle:
                    "Choose what you’re best at so we can match you with the right customers.",
                child: _buildSpecialties(),
              ),
              _sectionCard(
                title: "Contact & location",
                child: _buildContactAndLocation(),
              ),
              _sectionCard(
                title: "Experience & rate",
                child: _buildExperienceAndRate(),
              ),
              _sectionCard(
                title: "Training methods",
                child: _buildTrainingMethods(),
              ),
              _sectionCard(
                title: "Work images",
                subtitle:
                    "Add photos of you training clients, at the gym, or transformations.",
                child: _buildWorkImages(),
              ),
              const SizedBox(height: 12),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Save Profile",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
