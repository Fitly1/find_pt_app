// lib/edit_listings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'create_listing_page.dart';
import 'bottom_navigation_customers.dart';
import 'bottom_navigation.dart';
import 'listings_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF0B0D10);
const Color _surface = Color(0xFF171B22);
const Color _field = Color(0xFF252B35);
const Color _line = Color(0xFF343A46);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class EditListingsPage extends StatefulWidget {
  const EditListingsPage({super.key});

  @override
  State<EditListingsPage> createState() => _EditListingsPageState();
}

class _EditListingsPageState extends State<EditListingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String userRole = 'customer';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    });

    debugPrint('EditListingsPage: Loaded user role: $userRole');
  }

  Stream<QuerySnapshot> _userListingsStream() {
    return FirebaseFirestore.instance
        .collection('listings')
        .where('userId', isEqualTo: user?.uid)
        .where('deleted', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _editListing(
    Map<String, dynamic> listingData,
    String listingId,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListingPage(
          isEditing: true,
          existingData: listingData,
          listingId: listingId,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _addNewListing() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateListingPage(
          isEditing: false,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  bool get _isCustomer => userRole == 'customer';

  Widget _buildBottomNavigation() {
    return _isCustomer
        ? const BottomNavigationCustomers(currentIndex: 3)
        : const BottomNavigation(currentIndex: 3);
  }

  String _formatDate(Map<String, dynamic> data) {
    final Timestamp? createdAtTs = data['createdAt'] as Timestamp?;
    final Timestamp? timestampTs = data['timestamp'] as Timestamp?;
    final Timestamp? ts = createdAtTs ?? timestampTs;

    if (ts == null) return 'Unknown date';

    return DateFormat('dd MMM yyyy').format(ts.toDate());
  }

  List<String> _readSpecialties(Map<String, dynamic> data) {
    final value = data['specialties'];

    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: _ink,
        appBar: _buildAppBar(),
        body: const _NoUserState(),
        bottomNavigationBar: _buildBottomNavigation(),
      );
    }

    return Scaffold(
      backgroundColor: _ink,
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewListing,
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Listing',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _surface,
        onRefresh: () async {
          if (mounted) setState(() {});
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _userListingsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(error: snapshot.error);
            }

            if (!snapshot.hasData) {
              return const _LoadingState();
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const _EmptyState();
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              itemCount: docs.length + 1,
              separatorBuilder: (_, index) {
                if (index == 0) return const SizedBox(height: 14);
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PageIntro(
                    count: docs.length,
                    onAdd: _addNewListing,
                  );
                }

                final doc = docs[index - 1];
                final data = doc.data() as Map<String, dynamic>;
                final listingId = doc.id;

                final title = (data['title'] ?? 'Untitled').toString();
                final description = (data['description'] ?? '').toString();
                final location = (data['location'] ?? '').toString();
                final trainingMethod =
                    (data['trainingMethod'] ?? 'Not set').toString();
                final dateStr = _formatDate(data);
                final specialties = _readSpecialties(data);

                return _ListingCard(
                  title: title,
                  description: description,
                  location: location,
                  trainingMethod: trainingMethod,
                  date: dateStr,
                  specialties: specialties,
                  onEdit: () => _editListing(data, listingId),
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: true,
      backgroundColor: _ink,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ListingsPage(),
            ),
          );
        },
      ),
      title: const Text(
        'My Listings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _line),
      ),
    );
  }
}

/* ───────────────── Premium UI widgets ───────────────── */

class _PageIntro extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _PageIntro({
    required this.count,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final listingText =
        count == 1 ? '1 active listing' : '$count active listings';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _gold.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.list_alt_rounded,
              color: _gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage your requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  listingText,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final String title;
  final String description;
  final String location;
  final String trainingMethod;
  final String date;
  final List<String> specialties;
  final VoidCallback onEdit;

  const _ListingCard({
    required this.title,
    required this.description,
    required this.location,
    required this.trainingMethod,
    required this.date,
    required this.specialties,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.trim().isEmpty ? 'Untitled listing' : title.trim();
    final cleanDescription = description.trim();
    final cleanLocation =
        location.trim().isEmpty ? 'Location not selected' : location.trim();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: _gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _gold,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              if (cleanDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  cleanDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.location_on_outlined,
                    label: cleanLocation,
                  ),
                  _InfoPill(
                    icon: Icons.fitness_center_rounded,
                    label: trainingMethod,
                  ),
                  _InfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: date,
                  ),
                ],
              ),
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: specialties.take(4).map((specialty) {
                    return _SpecialtyChip(label: specialty);
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _gold,
            size: 15,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.11),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.playlist_add_rounded,
                  size: 38,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No listings yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a request so trainers can understand what you need help with.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoUserState extends StatelessWidget {
  const _NoUserState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _line),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: _gold,
              ),
              SizedBox(height: 16),
              Text(
                'No user found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please sign in to manage your listings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _danger.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Couldn’t load listings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          height: 150,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SkeletonBox(width: 42, height: 42, radius: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: 210,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
