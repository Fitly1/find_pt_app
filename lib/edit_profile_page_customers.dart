import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For uploading to Firebase Storage
import 'dart:io';

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

  // Use one controller for full name, which will display the combination of first and last names.
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // This will hold the remote image URL from Firestore (if any).
  String? _profileImageUrl;

  // We'll also keep a File reference if the user picks a new image.
  File? _newImageFile;

  // Local placeholder asset file name:
  final String _placeholderAsset = 'assets/default_profile.png';

  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load existing user data from Firestore and populate controllers.
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
          // Combine firstName and lastName to display as full name.
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

  /// Pick image from the gallery, upload to Firebase Storage, and update Firestore.
  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Convert XFile to a File
        final File file = File(pickedFile.path);
        setState(() {
          _newImageFile = file;
        });
        // Show a temporary message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // 1. Create a reference in Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();
        final profileImagesRef =
            storageRef.child('profileImages/${user.uid}.jpg');

        // 2. Upload the file
        await profileImagesRef.putFile(file);
        if (!mounted) return;

        // 3. Get the download URL
        final downloadUrl = await profileImagesRef.getDownloadURL();
        if (!mounted) return;

        // 4. Update Firestore with the new URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profileImageUrl': downloadUrl,
        });
        if (!mounted) return;

        // 5. Update local state to show the new image immediately
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

  /// Save the updated profile to Firestore.
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Split the combined full name into firstName and lastName.
          List<String> names = _fullNameController.text.trim().split(' ');
          String firstName = names.isNotEmpty ? names.first : '';
          String lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'firstName': firstName,
            'lastName': lastName,
            'phone': _phoneController.text.trim(),
            // 'profileImageUrl': _profileImageUrl, // Already updated in _pickAndUploadImage()
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);

          // <-- Security integration: Save last profile update timestamp securely.
          await secureStorage.writeData(
            'last_profile_update_customer',
            DateTime.now().toIso8601String(),
          );
          // Retrieve and print the timestamp from secure storage for debugging.
          String? updateTimestamp =
              await secureStorage.readData('last_profile_update_customer');
          debugPrint("Last profile update timestamp: $updateTimestamp");
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
    // Determine which image to show in the avatar:
    // 1) Newly picked file, 2) Firestore URL, or 3) Local asset placeholder.
    Widget avatarChild;
    if (_newImageFile != null) {
      avatarChild = Image.file(_newImageFile!, fit: BoxFit.cover);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      avatarChild = Image.network(_profileImageUrl!, fit: BoxFit.cover);
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
              // Profile Picture with camera icon overlay.
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
              // Full Name Field (prefilled with combined first and last names).
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
              // Email Field (read-only).
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              // Phone Number Field.
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
