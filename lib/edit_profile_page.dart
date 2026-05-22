// lib/edit_profile_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'trainer_home_page.dart';

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
  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _borderStrong = Color(0xFF343A46);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _textSoft = Color(0xFF7E8794);
  static const Color _error = Color(0xFFE57373);
  static const Color _darkText = Color(0xFF121212);

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  Map<String, dynamic>? _selectedSuburb;
  List<Map<String, dynamic>> _suburbs = [];

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final List<File> _workImages = [];
  List<String> _savedWorkImageUrls = [];
  String _existingImageUrl = '';

  late final List<MultiSelectItem<String>> _specialtiesItems =
      kSpecialties.map((s) => MultiSelectItem<String>(s, s)).toList();

  List<String> _selectedSpecialties = [];
  List<String> _selectedMethods = [];

  int? _experienceValue;
  String? _experienceUnit;

  bool _isSaving = false;

  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_refreshHeader);
    _lastNameController.addListener(_refreshHeader);
    _experienceValue = 1;
    _experienceUnit = 'Years';
    _loadProfileData();
    _loadSuburbs();
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_refreshHeader);
    _lastNameController.removeListener(_refreshHeader);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _refreshHeader() {
    if (mounted) setState(() {});
  }

  String _capitalise(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  String _formatLocation(Map<String, dynamic> suburb) {
    return '${suburb['Suburb']}, ${suburb['State']} (${suburb['Postcode']})';
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: _textSoft,
        fontWeight: FontWeight.w500,
      ),
      prefixStyle: const TextStyle(
        color: _textMain,
        fontWeight: FontWeight.w800,
      ),
      counterStyle: const TextStyle(
        color: _textSoft,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _gold, width: 1.3),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13.2,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  void _showSnack(
    String message, {
    Color backgroundColor = _raised,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
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

      debugPrint('✅ Loaded ${_suburbs.length} suburbs.');
    } catch (e) {
      debugPrint('❌ Error loading suburbs data: $e');
    }
  }

  Future<void> _loadProfileData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _emailController.text = user.email ?? '';

    final doc = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    if (!mounted) return;

    setState(() {
      _firstNameController.text = data['firstName'] ?? '';
      _lastNameController.text = data['lastName'] ?? '';
      _descriptionController.text = data['description'] ?? '';

      _selectedSpecialties = (data['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      _mobileController.text = data['mobile'] ?? '';
      _locationController.text = data['location'] ?? '';

      if (data['experience'] != null) {
        final expString = data['experience'].toString().toLowerCase();
        final numericPart =
            int.tryParse(expString.replaceAll(RegExp(r'[^0-9]'), ''));

        if (expString.contains('month')) {
          _experienceUnit = 'Months';
          _experienceValue = numericPart ?? 0;
        } else if (expString.contains('year')) {
          _experienceUnit = 'Years';
          _experienceValue = numericPart ?? 0;
        } else {
          _experienceValue = int.tryParse(data['experience'].toString()) ?? 0;
          _experienceUnit = 'Years';
        }
      }

      _rateController.text = data['rate']?.toString() ?? '';

      _selectedMethods = (data['trainingMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      _existingImageUrl = data['profileImageUrl'] ?? '';

      _savedWorkImageUrls = (data['workImageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    });
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(
      tempDir.path,
      '${path.basenameWithoutExtension(file.path)}_compressed${path.extension(file.path)}',
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
      debugPrint('Error downloading image: $e');
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
      'cropped_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
      _showSnack(
        'Profile image is still over 500KB after compression.',
        backgroundColor: _error,
      );
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
      _showSnack(
        'Failed to download existing image.',
        backgroundColor: _error,
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = path.join(tempDir.path, 'existing_image.jpg');
    final imageFile = await File(filePath).writeAsBytes(imageBytes);

    final File? processedFile = await _cropAndCompressImage(imageFile);
    if (processedFile == null) return;

    final bytes = await processedFile.length();

    if (bytes > 500 * 1024) {
      _showSnack(
        'Image is still over 500KB after compression.',
        backgroundColor: _error,
      );
      return;
    }

    setState(() {
      _profileImage = processedFile;
    });
  }

  Future<String> _uploadProfileImage() async {
    if (_profileImage == null) return '';

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('trainer_images')
          .child('${user.uid}.jpg');

      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      await uploadTask.whenComplete(() => null);

      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return '';
    }
  }

  Future<void> _pickWorkImage() async {
    if (_workImages.length + _savedWorkImageUrls.length >= 6) {
      _showSnack(
        'Maximum of 6 work images allowed.',
        backgroundColor: _error,
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final compressedFile = await _compressImage(file);

    if (compressedFile == null) {
      _showSnack(
        'Image compression failed.',
        backgroundColor: _error,
      );
      return;
    }

    final bytes = await compressedFile.length();

    if (bytes > 500 * 1024) {
      _showSnack(
        'Work image is still over 500KB after compression.',
        backgroundColor: _error,
      );
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

  List<dynamic> get _combinedWorkImages => [
        ..._savedWorkImageUrls,
        ..._workImages,
      ];

  Future<List<String>> _uploadWorkImages() async {
    final List<String> workImageUrls = [];
    final user = FirebaseAuth.instance.currentUser!;

    for (final image in _workImages) {
      try {
        final String fileName =
            '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('trainer_work_images')
            .child(fileName);

        final UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask.whenComplete(() => null);

        final url = await storageRef.getDownloadURL();
        workImageUrls.add(url);
      } catch (e) {
        debugPrint('Error uploading work image: $e');
      }
    }

    return workImageUrls;
  }

  void _showLocationBottomSheet() {
    final searchController =
        TextEditingController(text: _locationController.text);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.48,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: _border),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Search location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Choose the suburb customers should find you in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TypeAheadField<Map<String, dynamic>>(
                      controller: searchController,
                      suggestionsCallback: (pattern) {
                        if (pattern.trim().isEmpty) return [];

                        final lower = pattern.toLowerCase().trim();

                        final matches = _suburbs.where((item) {
                          final suburb =
                              item['Suburb']?.toString().toLowerCase() ?? '';
                          final postcode = item['Postcode']?.toString() ?? '';

                          return suburb.contains(lower) ||
                              postcode.contains(pattern.trim());
                        }).toList();

                        return matches.take(12).toList();
                      },
                      itemBuilder: (context, suggestion) {
                        final display = _formatLocation(suggestion);

                        return Container(
                          color: _card,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              display,
                              style: const TextStyle(
                                color: _textMain,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              suggestion['State']?.toString() ?? '',
                              style: const TextStyle(
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                      onSelected: (suggestion) {
                        setState(() {
                          _locationController.text =
                              _formatLocation(suggestion);
                          _selectedSuburb = suggestion;
                        });

                        Navigator.pop(context);
                      },
                      emptyBuilder: (context) {
                        return Container(
                          color: _card,
                          padding: const EdgeInsets.all(14),
                          child: const Text(
                            'No suburb or postcode found.',
                            style: TextStyle(
                              color: _textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      builder: (context, textController, focusNode) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          autofocus: true,
                          cursorColor: _gold,
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _fieldDecoration(
                            'Suburb or postcode',
                            hint: 'e.g. Seven Hills or 2147',
                            suffixIcon: const Icon(
                              Icons.search_rounded,
                              color: _textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tip: search by postcode if the suburb name is hard to find.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _afterSaveProfile(bool isActive) {
    _showSnack(
      'Profile saved successfully.',
      backgroundColor: _raised,
    );

    if (!isActive) {
      _showActivationPrompt();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const TrainerHomePage(
          showProfileCompleteMessage: true,
        ),
      ),
    );
  }

  void _showActivationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: _card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.16),
                    border: Border.all(color: _gold, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: _gold,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Activate profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your profile is saved, but membership is inactive. Activate it when you are ready to be visible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textMain,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Later',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_gold, _goldDeep],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _activateSubscription();
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            foregroundColor: _darkText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Activate',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _darkText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _activateSubscription() async {
    try {
      _showSnack('Loading checkout...');

      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');

      final result = await callable.call();

      if (!mounted) return;

      final sessionUrl = result.data['sessionUrl'];

      if (sessionUrl == null) {
        _showSnack(
          'Failed to get checkout URL.',
          backgroundColor: _error,
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

      _showSnack(
        'Error starting subscription.',
        backgroundColor: _error,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty) {
      _showSnack('First name is required.', backgroundColor: _error);
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      _showSnack('Last name is required.', backgroundColor: _error);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnack('Profile description is required.', backgroundColor: _error);
      return;
    }

    if (_selectedSpecialties.isEmpty) {
      _showSnack('Select at least one specialty.', backgroundColor: _error);
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showSnack('Location is required.', backgroundColor: _error);
      return;
    }

    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;

    if (rate <= 0) {
      _showSnack('Enter a valid hourly rate.', backgroundColor: _error);
      return;
    }

    if ((_profileImage == null) && (_existingImageUrl.isEmpty)) {
      _showSnack('Profile image is required.', backgroundColor: _error);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack(
          'Session expired. Please log in again.',
          backgroundColor: _error,
        );
        return;
      }

      final String uploadedImageUrl =
          _profileImage != null ? await _uploadProfileImage() : '';

      final String finalImageUrl =
          uploadedImageUrl.isNotEmpty ? uploadedImageUrl : _existingImageUrl;

      if (finalImageUrl.isEmpty) {
        _showSnack(
          'Could not upload profile image. Try another image.',
          backgroundColor: _error,
        );
        return;
      }

      final List<String> newWorkImageUrls = await _uploadWorkImages();
      final List<String> finalWorkImageUrls = [
        ..._savedWorkImageUrls,
        ...newWorkImageUrls,
      ];

      final formattedFirstName = _capitalise(_firstNameController.text.trim());
      final formattedLastName = _capitalise(_lastNameController.text.trim());
      final combinedName = '$formattedFirstName $formattedLastName'.trim();
      final experienceString =
          '${_experienceValue ?? 0} ${_experienceUnit ?? 'Years'}';

      final profileData = <String, dynamic>{
        'firstName': formattedFirstName,
        'firstName_lowerCase': formattedFirstName.toLowerCase(),
        'lastName': formattedLastName,
        'lastName_lowerCase': formattedLastName.toLowerCase(),
        'displayName': combinedName,
        'displayName_lowerCase': combinedName.toLowerCase(),
        'name': combinedName,
        'description': _descriptionController.text.trim(),
        'specialties': _selectedSpecialties,
        'mobile': _mobileController.text.trim(),
        'location': _locationController.text.trim(),
        'experience': experienceString,
        'rate': rate,
        'profileImageUrl': finalImageUrl,
        'workImageUrls': finalWorkImageUrls,
        'trainingMethods': _selectedMethods,
        'completed': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedSuburb != null) {
        final lat =
            double.tryParse(_selectedSuburb!['Latitude'].toString()) ?? 0.0;
        final lng =
            double.tryParse(_selectedSuburb!['Longitude'].toString()) ?? 0.0;

        if (lat != 0.0 || lng != 0.0) {
          profileData['geoLocation'] = {'lat': lat, 'lng': lng};
        }
      }

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      await secureStorage.writeData(
        'last_profile_update',
        DateTime.now().toIso8601String(),
      );

      final doc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .get();

      var isActive = (doc.data() as Map<String, dynamic>)['isActive'] ?? false;

      if (!isTrainerPaymentsEnabled) {
        isActive = true;
      }

      if (!mounted) return;

      setState(() => _isSaving = false);

      _afterSaveProfile(isActive);
    } catch (e) {
      debugPrint('Save profile failed: $e');

      if (!mounted) return;

      _showSnack(
        'Failed to save profile. Please try again.',
        backgroundColor: _error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

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
                  Container(
                    height: 124,
                    width: 124,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_gold, _goldDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: _raised,
                      backgroundImage: avatarProvider,
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: InkWell(
                      onTap: _pickProfileImage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _card,
                            width: 2.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: _darkText,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_existingImageUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _reCropExistingImage,
                  icon: const Icon(
                    Icons.crop_rounded,
                    color: _gold,
                    size: 18,
                  ),
                  label: const Text(
                    'Re-crop existing',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          liveName.isEmpty ? 'Your trainer profile' : liveName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textMain,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add a clear face photo. This builds trust fastest.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textMuted,
            fontSize: 13.5,
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
          cursorColor: _gold,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration('First name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          cursorColor: _gold,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration('Last name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          readOnly: true,
          style: const TextStyle(
            color: _textMuted,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration('Email address'),
        ),
      ],
    );
  }

  Widget _buildBio() {
    return TextField(
      controller: _descriptionController,
      maxLength: 1000,
      maxLines: 5,
      minLines: 4,
      cursorColor: _gold,
      style: const TextStyle(
        color: _textMain,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        'Profile description',
        hint: 'Who do you help? What is your training style? Any key certs?',
      ),
    );
  }

  Widget _buildSpecialties() {
    return MultiSelectDialogField<String>(
      items: _specialtiesItems,
      title: const Text(
        'Specialties',
        style: TextStyle(
          color: _textMain,
          fontWeight: FontWeight.w900,
        ),
      ),
      buttonText: Text(
        _selectedSpecialties.isEmpty
            ? 'Select specialties'
            : '${_selectedSpecialties.length} selected',
        style: const TextStyle(
          color: _textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      buttonIcon: const Icon(
        Icons.fitness_center_rounded,
        color: _gold,
      ),
      initialValue: _selectedSpecialties,
      searchable: true,
      listType: MultiSelectListType.CHIP,
      backgroundColor: _card,
      selectedColor: _gold,
      checkColor: _darkText,
      itemsTextStyle: const TextStyle(
        color: _darkText,
        fontWeight: FontWeight.w900,
        fontSize: 14.5,
      ),
      selectedItemsTextStyle: const TextStyle(
        color: _darkText,
        fontWeight: FontWeight.w900,
        fontSize: 14.5,
      ),
      searchTextStyle: const TextStyle(
        color: _textMain,
        fontWeight: FontWeight.w700,
      ),
      searchHintStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w600,
      ),
      confirmText: const Text(
        'Done',
        style: TextStyle(
          color: _gold,
          fontWeight: FontWeight.w900,
        ),
      ),
      cancelText: const Text(
        'Cancel',
        style: TextStyle(
          color: _textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
      decoration: BoxDecoration(
        color: _raisedSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      chipDisplay: MultiSelectChipDisplay<String>(
        chipColor: _gold,
        textStyle: const TextStyle(
          color: _darkText,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
        onTap: (value) {
          setState(() => _selectedSpecialties.remove(value));
        },
      ),
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
          keyboardType: TextInputType.phone,
          cursorColor: _gold,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(
            'Mobile number',
            hint: 'Optional',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _showLocationBottomSheet,
            icon: const Icon(
              Icons.search_rounded,
              color: _gold,
              size: 20,
            ),
            label: Text(
              _locationController.text.isEmpty
                  ? 'Select suburb or postcode'
                  : _locationController.text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textMain,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: _raisedSoft,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
              'Experience',
              style: TextStyle(
                color: _textMain,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _experienceValue,
                dropdownColor: _card,
                style: const TextStyle(
                  color: _textMain,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _fieldDecoration(''),
                items: List.generate(51, (index) => index)
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _experienceValue = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ToggleButtons(
          isSelected: [
            _experienceUnit == 'Years',
            _experienceUnit == 'Months',
          ],
          borderRadius: BorderRadius.circular(14),
          borderColor: _border,
          selectedBorderColor: _gold,
          color: _textMuted,
          selectedColor: _darkText,
          fillColor: _gold,
          constraints: const BoxConstraints(
            minHeight: 42,
            minWidth: 120,
          ),
          onPressed: (index) {
            setState(() {
              _experienceUnit = index == 0 ? 'Years' : 'Months';
            });
          },
          children: const [
            Text(
              'Years',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Months',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          cursorColor: _gold,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(
            'Hourly rate',
            prefixText: '\$ ',
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingMethods() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _methodChip('Online'),
        _methodChip('Face-to-Face'),
      ],
    );
  }

  Widget _methodChip(String label) {
    final selected = _selectedMethods.contains(label);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _selectedMethods.add(label);
          } else {
            _selectedMethods.remove(label);
          }
        });
      },
      backgroundColor: _raisedSoft,
      selectedColor: _gold,
      checkmarkColor: _darkText,
      side: BorderSide(
        color: selected ? _gold : _border,
      ),
      labelStyle: TextStyle(
        color: selected ? _darkText : _textMain,
        fontWeight: FontWeight.w900,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    );
  }

  Widget _buildWorkImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add up to 6 images. Use training, gym, or transformation photos.',
          style: TextStyle(
            color: _textMuted,
            fontSize: 13.2,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _combinedWorkImages.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
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
                      borderRadius: BorderRadius.circular(14),
                      child: Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: InkWell(
                      onTap: () => _removeWorkImage(index),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return InkWell(
              onTap: _pickWorkImage,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: _raisedSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _border,
                    width: 1.1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: _gold,
                    size: 30,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isSaving
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: _isSaving ? _borderStrong : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!_isSaving)
              BoxShadow(
                color: _gold.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: _darkText,
            disabledForegroundColor: _textMuted,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                  ),
                )
              : const Text(
                  'Save profile',
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          backgroundColor: _bgTop,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _textMain),
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: _EditProfileBackground()),
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  child: Column(
                    children: [
                      _sectionCard(
                        title: 'Profile photo',
                        subtitle:
                            'Customers trust clear trainer photos more than logos or blank profiles.',
                        child: _buildProfileHeader(),
                      ),
                      _sectionCard(
                        title: 'Basic details',
                        child: _buildBasicDetails(),
                      ),
                      _sectionCard(
                        title: 'About you',
                        subtitle:
                            'Keep it clear. Who you help, how you train, and why customers should trust you.',
                        child: _buildBio(),
                      ),
                      _sectionCard(
                        title: 'Specialties',
                        subtitle:
                            'Choose what you are best at so Fitly can match you better later.',
                        child: _buildSpecialties(),
                      ),
                      _sectionCard(
                        title: 'Contact & location',
                        subtitle:
                            'Your suburb helps customers find nearby trainers.',
                        child: _buildContactAndLocation(),
                      ),
                      _sectionCard(
                        title: 'Experience & rate',
                        child: _buildExperienceAndRate(),
                      ),
                      _sectionCard(
                        title: 'Training methods',
                        child: _buildTrainingMethods(),
                      ),
                      _sectionCard(
                        title: 'Work images',
                        child: _buildWorkImages(),
                      ),
                      const SizedBox(height: 8),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileBackground extends StatelessWidget {
  const _EditProfileBackground();

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _gold = Color(0xFFE7B95C);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -120,
          child: Container(
            height: 290,
            width: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.11),
            ),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -140,
          child: Container(
            height: 340,
            width: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.07),
            ),
          ),
        ),
      ],
    );
  }
}
