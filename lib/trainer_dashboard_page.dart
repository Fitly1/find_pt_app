// trainer_dashboard_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'bottom_navigation.dart';
import 'invoice_generator_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
/* ─────────────────────────  STATE  ───────────────────────── */
  bool _loading = true;
  bool _uploadingLogo = false;
  String? _error;
  String? _logoUrl;

  final _formKey = GlobalKey<FormState>();
  final _bizCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();

  // Notes
  final _noteTitleCtrl = TextEditingController();
  final _noteDescCtrl = TextEditingController();

  late final String _trainerId;

/* ───────────────────────  LIFECYCLE  ─────────────────────── */
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'Not signed in';
      _loading = false;
      return;
    }
    _trainerId = user.uid;
    _loadSettings();
  }

  @override
  void dispose() {
    _bizCtrl.dispose();
    _abnCtrl.dispose();
    _addrCtrl.dispose();
    _emailCtrl.dispose();
    _bankCtrl.dispose();
    _prefixCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteDescCtrl.dispose();
    super.dispose();
  }

/* ───────────────────  FIRESTORE HELPERS  ─────────────────── */
  Future<void> _loadSettings() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .get();

      final inv = snap.data()?['invoiceSettings'] is Map
          ? Map<String, dynamic>.from(snap.data()!['invoiceSettings'])
          : <String, dynamic>{};

      _bizCtrl.text = inv['businessName'] ?? '';
      _abnCtrl.text = inv['abn'] ?? '';
      _addrCtrl.text = inv['address'] ?? '';
      _emailCtrl.text = inv['email'] ?? '';
      _bankCtrl.text = inv['bankDetails'] ?? '';
      _prefixCtrl.text = inv['invoicePrefix'] ?? '';
      _logoUrl = inv['logoUrl'];
    } catch (e) {
      _error = 'Failed to load settings: $e';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .update({
        'invoiceSettings.businessName': _bizCtrl.text.trim(),
        'invoiceSettings.abn': _abnCtrl.text.trim(),
        'invoiceSettings.address': _addrCtrl.text.trim(),
        'invoiceSettings.email': _emailCtrl.text.trim(),
        'invoiceSettings.bankDetails': _bankCtrl.text.trim(),
        'invoiceSettings.invoicePrefix': _prefixCtrl.text.trim(),
        if (_logoUrl != null) 'invoiceSettings.logoUrl': _logoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

/* ───────────── NOTES HELPERS ───────────── */
  Future<void> _saveNote({String? id}) async {
    final title = _noteTitleCtrl.text.trim();
    if (title.isEmpty) return;
    final desc = _noteDescCtrl.text.trim();

    final data = {
      'trainerId': _trainerId,
      'title': title,
      'description': desc,
      'timestamp': Timestamp.now(),
    };

    if (id == null) {
      await FirebaseFirestore.instance.collection('trainer_notes').add(data);
    } else {
      await FirebaseFirestore.instance
          .collection('trainer_notes')
          .doc(id)
          .update({'title': title, 'description': desc});
    }
  }

  Future<void> _deleteNote(String id) async {
    await FirebaseFirestore.instance
        .collection('trainer_notes')
        .doc(id)
        .delete();
  }

/* ────────────────  IMAGE PICK / CROP / UPLOAD  ─────────────── */
  Future<void> _pickAndUploadLogo() async {
    try {
      final XFile? picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.png,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: const Color(0xFFFFA726),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped == null) return;

      setState(() => _uploadingLogo = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('trainer_logos')
          .child('$_trainerId.png');

      await ref.putFile(
        File(cropped.path),
        SettableMetadata(contentType: 'image/png'),
      );

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .update({'invoiceSettings.logoUrl': url});

      if (mounted) {
        setState(() {
          _logoUrl = url;
          _uploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload failed: $e')),
        );
      }
    }
  }

/* ────────────────────────  UI HELPERS  ────────────────────── */
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFFA726)),
        ),
      );

  void _openNoteDialog({DocumentSnapshot<Map<String, dynamic>>? note}) {
    _noteTitleCtrl.text = note?.data()?['title'] ?? '';
    _noteDescCtrl.text = note?.data()?['description'] ?? '';

    showDialog(
      context: context,
      builder: (_) {
        const primary = Color(0xFFFFA726);
        return AlertDialog(
          title: Text(note == null ? 'Add Note' : 'Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _noteTitleCtrl,
                  decoration: _dec('Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteDescCtrl,
                  decoration: _dec('Description'),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: () async {
                await _saveNote(id: note?.id);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

/* ─────────────────────────  BUILD  ───────────────────────── */
  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFFA726);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Dashboard'),
        backgroundColor: primary,
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /* ───────── FORM START ───────── */
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── NEW POSITION OF THE HEADING ───
                            const Text(
                              '🧾 Generate Your Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            /* LOGO PREVIEW & BUTTON */
                            Center(
                              child: Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: _logoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          _logoUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Center(
                                        child: Text('No logo uploaded'),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primary),
                                onPressed:
                                    _uploadingLogo ? null : _pickAndUploadLogo,
                                child: Text(
                                  _logoUrl == null
                                      ? 'Upload Logo'
                                      : 'Change Logo',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            /* BUSINESS / INVOICE FIELDS */
                            TextFormField(
                              controller: _bizCtrl,
                              decoration: _dec('Business Name *'),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _abnCtrl,
                              decoration: _dec('ABN'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addrCtrl,
                              decoration: _dec('Address'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: _dec('Contact Email / Phone'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bankCtrl,
                              decoration: _dec('Payment Instructions'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _prefixCtrl,
                              decoration:
                                  _dec('Invoice Number Prefix (Optional)'),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primary),
                                onPressed: _saveSettings,
                                child: const Text('Save Business Details'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      /* ───────── NAVIGATE TO GENERATOR ───────── */
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primary),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Generate Invoice'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InvoiceGeneratorPage(trainerId: _trainerId),
                              ),
                            );
                          },
                        ),
                      ),

                      /* ───────── MODERN DIVIDER ───────── */
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child:
                                Divider(color: Colors.grey.shade400, height: 1),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Trainer Notes 📝',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child:
                                Divider(color: Colors.grey.shade400, height: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      /* ───────── NOTES FEATURE ───────── */
                      ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: primary),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Note'),
                        onPressed: () => _openNoteDialog(),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('trainer_notes')
                            .where('trainerId', isEqualTo: _trainerId)
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Text('⚠️ ${snap.error}');
                          }
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snap.hasData || snap.data!.docs.isEmpty) {
                            return const Text('No notes yet');
                          }

                          final docs = snap.data!.docs;

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (_, i) {
                              final doc = docs[i];
                              return ListTile(
                                title: Text(doc['title'] ?? ''),
                                subtitle: Text(doc['description'] ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () =>
                                          _openNoteDialog(note: doc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      onPressed: () => _deleteNote(doc.id),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }
}
