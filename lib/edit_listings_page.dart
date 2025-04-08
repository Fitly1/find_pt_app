import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'create_listing_page.dart'; // ✅ The new version that supports `isEditing`
import 'bottom_navigation_customers.dart'; // Customer bottom nav
import 'bottom_navigation.dart'; // Trainer bottom nav
import 'listings_page.dart'; // Import ListingsPage for back navigation
import 'package:shared_preferences/shared_preferences.dart';

class EditListingsPage extends StatefulWidget {
  const EditListingsPage({super.key});

  @override
  State<EditListingsPage> createState() => _EditListingsPageState();
}

class _EditListingsPageState extends State<EditListingsPage> {
  final user = FirebaseAuth.instance.currentUser;
  String userRole = 'customer'; // default role

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'customer';
    });
    debugPrint("EditListingsPage: Loaded user role: $userRole");
  }

  /// Stream of listings where userId == current user's ID
  Stream<QuerySnapshot> _userListingsStream() {
    return FirebaseFirestore.instance
        .collection('listings')
        .where('userId', isEqualTo: user?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// When tapping the edit button, navigate to CreateListingPage in edit mode
  void _editListing(Map<String, dynamic> listingData, String listingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListingPage(
          isEditing: true,
          existingData: listingData,
          listingId: listingId,
        ),
      ),
    );
  }

  /// Button for creating a new listing.
  void _addNewListing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateListingPage(
          isEditing: false,
        ),
      ),
    );
  }

  /// Returns the appropriate bottom navigation widget based on the user's role.
  Widget _buildBottomNavigation() {
    bool isCustomer = (userRole == 'customer');
    return isCustomer
        ? const BottomNavigationCustomers(currentIndex: 3)
        : const BottomNavigation(currentIndex: 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // For customers, pressing back should take them to ListingsPage.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ListingsPage()),
            );
          },
        ),
        title: const Text("My Listings"),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _userListingsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text("No listings found for your account."));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final listingId = docs[index].id;

              // Basic fields
              final title = data["title"] ?? "Untitled";
              final description = data["description"] ?? "";
              final location = data["location"] ?? "";

              // Use createdAt if available; otherwise, fall back to timestamp
              final Timestamp? createdAtTs = data["createdAt"] as Timestamp?;
              final Timestamp? ts =
                  createdAtTs ?? data["timestamp"] as Timestamp?;
              final dateStr = ts != null
                  ? DateFormat('dd MMM yyyy').format(ts.toDate())
                  : "Unknown date";

              return ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    "Location: $location\n$description\nPosted on: $dateStr"),
                trailing: IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color.fromARGB(255, 255, 167, 38)),
                  onPressed: () => _editListing(data, listingId),
                ),
              );
            },
          );
        },
      ),
      // Optional button for adding a new listing
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
        onPressed: _addNewListing,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
