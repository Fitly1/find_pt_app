import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For uploading to Firebase Storage
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Make sure to import Crashlytics
import 'package:cached_network_image/cached_network_image.dart'; // Import cached_network_image

// Import your secure storage service
import 'secure_storage_service.dart';

class EditProfilePageCustomers extends StatefulWidget {
  const EditProfilePageCustomers({super.key});

  @override
  EditProfilePageCustomersState createState() =>
      EditProfilePageCustomersState();
}

class EditProfilePageCustomersState extends State<EditProfilePageCustomers> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _profileImageUrl;
  File? _newImageFile;
  final String _placeholderAsset = 'assets/default_profile.png';
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final String firstName = data?['firstName'] ?? '';
          final String lastName = data?['lastName'] ?? '';
          if (!mounted) return;
          setState(() {
            _fullNameController.text = '$firstName $lastName';
            _emailController.text = data?['email'] ?? '';
            _phoneController.text = data?['phone'] ?? '';
            _profileImageUrl = data?['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading existing data: $e");
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        setState(() {
          _newImageFile = file;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final storageRef = FirebaseStorage.instance.ref();
        final profileImagesRef =
            storageRef.child('profileImages/${user.uid}.jpg');

        await profileImagesRef.putFile(file);
        if (!mounted) return;

        final downloadUrl = await profileImagesRef.getDownloadURL();
        if (!mounted) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profileImageUrl': downloadUrl,
        });
        if (!mounted) return;

        setState(() {
          _profileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated!')),
        );
      }
    } catch (e) {
      debugPrint("Error picking/uploading image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // split full name
          List<String> names = _fullNameController.text.trim().split(' ');
          String firstName = names.isNotEmpty ? names.first : '';
          String lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

          // build combined name once
          final fullName = '$firstName $lastName'.trim();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'firstName': firstName,
            'firstName_lowerCase': firstName.toLowerCase(),
            'lastName': lastName,
            'lastName_lowerCase': lastName.toLowerCase(),
            'displayName': fullName, // ← added
            'displayName_lowerCase': fullName.toLowerCase(), // ← added
            'phone': _phoneController.text.trim(),
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);

          await secureStorage.writeData(
            'last_profile_update_customer',
            DateTime.now().toIso8601String(),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;

    if (_newImageFile != null) {
      avatarChild = Image.file(_newImageFile!, fit: BoxFit.cover);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      avatarChild = CachedNetworkImage(
        imageUrl: _profileImageUrl!,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: 'Profile image failed to load',
          );
          return Image.asset(
            _placeholderAsset,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      avatarChild = Image.asset(_placeholderAsset, fit: BoxFit.cover);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: avatarChild,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black87,
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 24),
                        onPressed: _pickAndUploadImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
