import 'package:flutter/material.dart';
import 'secure_storage_service.dart'; // Import your secure storage service

class CreateAccountPage extends StatefulWidget {
  final bool isPersonalTrainer;

  const CreateAccountPage({super.key, required this.isPersonalTrainer});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  void _signUp() async {
    // Write the current timestamp securely.
    await secureStorage.writeData(
      'last_account_creation',
      DateTime.now().toIso8601String(),
    );
    if (!mounted) return;

    // Read the stored timestamp for debugging.
    String? timestamp = await secureStorage.readData('last_account_creation');
    if (!mounted) return;
    debugPrint("Account creation timestamp: $timestamp");

    // Use context after all async work is complete.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account created (simulated)!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isPersonalTrainer ? 'Trainer Signup' : 'Customer Signup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: 'Email'),
            ),
            const TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (widget.isPersonalTrainer)
              const Column(
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Specialization'),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Location'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signUp,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
