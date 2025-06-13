import 'package:flutter/material.dart';

class TrainerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> trainers;

  TrainerSearchDelegate(this.trainers);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = trainers
        .where((trainer) =>
            trainer['name'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final trainer = results[index];
        return ListTile(
          title: Text(trainer['name']),
          subtitle: Text(trainer['suburb']),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerProfilePage(
                  name: trainer['name'],
                  specialties: trainer['specialties'],
                  rating: trainer['rating'],
                  suburb: trainer['suburb'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = trainers
        .where((trainer) =>
            trainer['name'].toLowerCase().startsWith(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final trainer = suggestions[index];
        return ListTile(
          title: Text(trainer['name']),
          onTap: () {
            query = trainer['name'];
            showResults(context);
          },
        );
      },
    );
  }
}

class TrainerProfilePage extends StatelessWidget {
  final String name;
  final List<String> specialties;
  final double rating;
  final String suburb;

  const TrainerProfilePage({
    required this.name,
    required this.specialties,
    required this.rating,
    required this.suburb,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Suburb: $suburb',
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Specialties:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Wrap(
              spacing: 8.0,
              children: specialties.map((specialty) {
                return Chip(label: Text(specialty));
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 4),
                Text(
                  rating.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
