import 'package:flutter/material.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

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
        title: const Text('Refund Policy'),
        backgroundColor: const Color(0xFFFFA726), // Brand orange
      ),
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: ListView(
          children: [
            // Main Title (Centered)
            const Text(
              'Refund Policy',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32, thickness: 2),

            // Section 1: Overview
            _buildSectionTitle('1. Overview'),
            _buildSectionContent(
              'Fitly ("the Platform") aims to provide a fair and transparent refund process for all subscription payments made by trainers. By using the Platform, you agree to the terms outlined in this Refund Policy.',
            ),

            // Section 2: Subscription Fees
            _buildSectionTitle('2. Subscription Fees'),
            _buildSectionContent(
              '• Subscription fees paid by trainers are non-refundable once the subscription period begins.\n'
              '• This includes situations where a trainer terminates their subscription mid-month or fails to utilize the Platform’s services during the subscription period.',
            ),

            // Section 3: Exceptional Circumstances
            _buildSectionTitle('3. Exceptional Circumstances'),
            _buildSectionContent(
              'Refunds may be considered in exceptional circumstances, including but not limited to:\n\n'
              '• Duplicate payments made in error.\n'
              '• Platform functionality issues that prevent trainers from accessing or using the Platform’s core services for an extended period (verified by our support team).\n'
              '• Any other circumstances deemed reasonable by Fitly’s management at their sole discretion.',
            ),

            // Section 4: Refund Request Process
            _buildSectionTitle('4. Refund Request Process'),
            _buildSectionContent(
              'To request a refund:\n\n'
              '• Contact our support team at support@fitly.live within 14 days of the payment date.\n'
              '• Provide detailed information, including the reason for the refund request and proof of payment (e.g., receipt or transaction ID).\n'
              '• Our team will review your request and notify you of the outcome within 7 business days.',
            ),

            // Section 5: Processing Refunds
            _buildSectionTitle('5. Processing Refunds'),
            _buildSectionContent(
              '• Approved refunds will be processed to the original payment method within 10 business days.\n'
              '• Refunds may take additional time to appear in your account depending on your financial institution’s policies.',
            ),

            // Section 6: Non-Refundable Situations
            _buildSectionTitle('6. Non-Refundable Situations'),
            _buildSectionContent(
              'Refunds will not be provided for:\n\n'
              '• Change of mind after the subscription period begins.\n'
              '• Failure to cancel the subscription before the next billing cycle.\n'
              '• Non-usage of the Platform’s services during the subscription period.',
            ),

            // Section 7: Changes to This Refund Policy
            _buildSectionTitle('7. Changes to This Refund Policy'),
            _buildSectionContent(
              'Fitly reserves the right to modify this Refund Policy at any time. Changes will be posted on the Platform, and continued use of the Platform constitutes acceptance of the updated policy.',
            ),

            // Section 8: Contact Us
            _buildSectionTitle('8. Contact Us'),
            _buildSectionContent(
              'For any questions or concerns about this Refund Policy, please contact us at support@fitly.live.\n\n'
              'By using the Platform, you acknowledge that you have read and understood this Refund Policy and agree to its terms.',
            ),

            // Section 9: Subscription Cancellation and Reactivation
            _buildSectionTitle('9. Subscription Cancellation and Reactivation'),
            _buildSectionContent(
              '• Subscription fees are non-refundable, and if a trainer cancels their subscription, any unused portion of the current billing cycle may be applied as credit. If reactivated shortly after cancellation, this leftover credit may reduce the next charge. \n\n'
              '• For clarity and consistent billing, reactivations are processed as a full-price charge, and any remaining credit is cleared. \n\n'
              '• If no additional payment is due upon reactivation (i.e., a zero-dollar final charge), no invoice will be generated. \n\n'
              '• If you have any questions about your final charge or credit applied, please contact our support team at support@fitly.live.',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
