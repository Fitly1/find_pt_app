import 'package:flutter/material.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  String? _selectedSuburb;
  final List<String> _selectedTrainingMethods = [];
  final List<String> _suburbs = [
    'Sydney',
    'Melbourne',
    'Brisbane',
    'Perth',
    'Adelaide',
  ];
  final List<String> _trainingMethods = ['One-on-One', 'Online', 'Group'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search by Suburb',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select a suburb',
              ),
              items: _suburbs
                  .map((suburb) => DropdownMenuItem(
                        value: suburb,
                        child: Text(suburb),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSuburb = value;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Filter by Training Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Column(
              children: _trainingMethods.map((method) {
                return CheckboxListTile(
                  title: Text(method),
                  value: _selectedTrainingMethods.contains(method),
                  onChanged: (bool? selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedTrainingMethods.add(method);
                      } else {
                        _selectedTrainingMethods.remove(method);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    if (_selectedSuburb == null && _selectedTrainingMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one filter.')),
      );
      return;
    }

    // Simulate filter application
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filters applied:\n'
          'Suburb: ${_selectedSuburb ?? "Any"}\n'
          'Training Methods: ${_selectedTrainingMethods.join(", ")}',
        ),
      ),
    );
  }
}
