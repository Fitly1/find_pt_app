import 'package:flutter/material.dart';

class SearchFilterPage extends StatelessWidget {
  const SearchFilterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Filters'),
      ),
      body: const Center(
        child: Text('Search Filter Page'),
      ),
    );
  }
}
