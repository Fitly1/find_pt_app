// privacy_policy_page.dart
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  // Helper for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper for section content
  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
      ),
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: ListView(
          children: [
            // Main Title (Centered)
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32, thickness: 2),

            // Section 1: Introduction
            _buildSectionTitle('1. Introduction'),
            _buildSectionContent(
              'Fitly ("the Platform") operates in Australia and is committed to protecting your privacy and complying with the Australian Privacy Act 1988. This Privacy Policy outlines how we collect, use, store, and protect your personal information when you use our Platform. By accessing or using the Platform, you consent to the practices described in this Privacy Policy.',
            ),

            // Section 2: Information We Collect
            _buildSectionTitle('2. Information We Collect'),
            _buildSectionContent(
              'We collect the following types of information:\n\n'
              '• Personal Information: Name, email address, phone number, and business details (e.g., ABN if applicable), trainer certifications, and insurance details, if provided. Information shared during chats, emails, or other communications with the Platform.\n\n'
              '• Usage Data: IP addresses, browser type, device information, interaction with the Platform, and cookies/tracking data for analytics and personalization.',
            ),

            // Section 3: How We Collect Information
            _buildSectionTitle('3. How We Collect Information'),
            _buildSectionContent(
              '• Directly provided by users during registration or account updates.\n'
              '• Through cookies, tracking technologies, and usage logs.\n'
              '• Information shared during communication with support or customer service.',
            ),

            // Section 4: How We Use Information
            _buildSectionTitle('4. How We Use Information'),
            _buildSectionContent(
              'We use the information to:\n\n'
              '• Provide and improve the Platform’s functionality.\n'
              '• Facilitate connections between Trainers and Clients.\n'
              '• Communicate with users regarding their accounts or the Platform.\n'
              '• Conduct analytics to improve user experience.\n'
              '• Comply with legal obligations and enforce our Terms of Service.',
            ),

            // Section 5: Sharing of Information
            _buildSectionTitle('5. Sharing of Information'),
            _buildSectionContent(
              'We may share your information with:\n\n'
              '• Service Providers: Currently, we share limited information with Stripe for payment processing.\n'
              '• Legal Authorities: When required by law or to protect our legal rights.\n'
              '• Clients and Trainers: Limited profile information to facilitate service connections.\n\n'
              'We do not share your personal information with any other third parties unless required by law.',
            ),

            // Section 6: Data Storage and Protection
            _buildSectionTitle('6. Data Storage and Protection'),
            _buildSectionContent(
              'All data is stored within Australia in our Forestore database. We implement industry-standard security measures to protect your data, including encryption during transmission, secure storage with restricted access, and regular security audits and assessments.',
            ),

            // Section 7: Data Retention
            _buildSectionTitle('7. Data Retention'),
            _buildSectionContent(
              'We retain personal information as long as necessary to provide our services or comply with legal obligations, and for up to 7 years post-account termination for compliance, legal, or dispute resolution purposes.',
            ),

            // Section 8: Cookies and Tracking
            _buildSectionTitle('8. Cookies and Tracking'),
            _buildSectionContent(
              'We use cookies to enhance user experience by remembering preferences and analyzing Platform usage via third-party tools. Users can control cookies through their browser settings, although this may affect some functionalities of the Platform.',
            ),

            // Section 9: User Rights
            _buildSectionTitle('9. User Rights'),
            _buildSectionContent(
              'You have the right to access, update, or correct your personal information by logging into your account or contacting us at support@fitly.live. You may request deletion of your data (subject to legal or contractual obligations), opt-out of marketing communications, or request that we remove your personal information.',
            ),

            // Section 10: Free Approach to Data Protection
            _buildSectionTitle('10. Free Approach to Data Protection'),
            _buildSectionContent(
              'In alignment with our commitment to free and open-source solutions:\n\n'
              '• We use open-source tools and default platform security configurations to ensure data protection.\n'
              '• No paid or proprietary data management systems are used unless specified.',
            ),

            // Section 11: Changes to This Privacy Policy
            _buildSectionTitle('11. Changes to This Privacy Policy'),
            _buildSectionContent(
              'We may update this Privacy Policy at any time without prior notice. Updates will be posted on the Platform, and continued use constitutes acceptance of the updated policy. Please review this policy periodically.',
            ),

            // Section 12: Regulatory Contact
            _buildSectionTitle('12. Regulatory Contact'),
            _buildSectionContent(
              'If you have concerns about your privacy or our data practices, you may contact the Office of the Australian Information Commissioner (OAIC).',
            ),

            // Section 13: Contact Us
            _buildSectionTitle('13. Contact Us'),
            _buildSectionContent(
              'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at support@fitly.live.\n\n'
              'By using the Platform, you acknowledge that you have read and understood this Privacy Policy and agree to our data collection, use, and sharing practices.',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
