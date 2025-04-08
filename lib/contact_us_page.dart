import 'package:flutter/material.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Brand-colored AppBar
      appBar: AppBar(
        title: const Text(
          'Contact Us / Support',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
        elevation: 0,
      ),
      // Gradient background for a modern look
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE0B2), // Light brand-based color
              Color(0xFFFFFFFF), // White at the bottom
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                // Make the area at least as tall as the screen
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // Let the Column take only the space it needs, while allowing scroll
                child: IntrinsicHeight(
                  // Align with negative vertical value to move content higher
                  child: Align(
                    alignment: const Alignment(0, -0.3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Support Icon
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            // ~20% opacity
                            color: Colors.white.withAlpha(51),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.support_agent,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Card with contact info
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 30.0,
                            ),
                            child: Column(
                              children: [
                                // Heading
                                const Text(
                                  'Need Assistance?',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Body text
                                const Text(
                                  'For support or any inquiries, reach out to us:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                // Selectable Email Link (for copying)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.email,
                                      color: Colors.blue,
                                      size: 26,
                                    ),
                                    SizedBox(width: 8),
                                    SelectableText(
                                      'support@fitly.live',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Office Hours
                                const Text(
                                  'Office Hours: Mon - Fri, 9:00 AM - 5:00 PM',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
