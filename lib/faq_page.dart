import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Updated FAQs with additional payment-related questions.
    final List<Map<String, String>> faqs = [
      {
        'question': 'How do I update my profile?',
        'answer':
            'Tap on "Edit Profile Details" in your profile page to update your information.'
      },
      {
        'question': 'How do I manage my payment options?',
        'answer':
            'Go to the Payment Options section to update your credit card or billing details.'
      },
      {
        'question': 'What if I forget my password?',
        'answer':
            'Use the "Forgot Password" option on the login page to reset your password.'
      },
      {
        'question': 'How do I contact support?',
        'answer':
            'Navigate to the Contact Us / Support section to send us a message.'
      },
      {
        'question': 'Are refunds available?',
        'answer':
            'No, refunds are not provided once a transaction is completed. Please review our Refund Policy for further details.'
      },
      {
        'question': 'Why am I not eligible for a refund?',
        'answer':
            'Our services are personalized and non-refundable. Please review our Refund Policy for more details.'
      },
      {
        'question': 'How do I dispute a charge?',
        'answer':
            'If you wish to dispute a charge, please contact our support team via email at account@fitly.com. Our team will assist you with the dispute resolution process.'
      },
      {
        'question': 'How do I update my email address?',
        'answer':
            'Your email address is managed through our authentication system. If you need to update it, please contact support at support@fitly.live.'
      },
      {
        'question': 'How do I report a bug or issue with the app?',
        'answer':
            'If you encounter any bugs or issues, please report them by emailing support@fitly.live with a detailed description of the problem.'
      },
      {
        'question': 'How do I delete my account?',
        'answer':
            'Account deletion requests are handled by our support team. Please contact support@fitly.live to initiate the process.'
      },
      {
        'question':
            'Why am I charged the full subscription price when reactivating my account?',
        'answer':
            'To maintain a consistent and predictable billing cycle, any unused balance from your previous subscription period is cleared when you cancel. This means that upon reactivation, you are charged the full subscription fee. This approach helps ensure clear pricing and avoids confusion over prorated amounts.'
      },
      {
        'question':
            'How is proration handled if I cancel or reactivate mid-cycle?',
        'answer':
            'Our billing system is designed to clear any remaining credit when a subscription is canceled. This ensures that when you reactivate your subscription, you are charged the full price for a new billing cycle rather than a prorated, partial amount.'
      },
      {
        'question':
            'What should I do if I do not receive an invoice or receipt?',
        'answer':
            'If you do not receive an invoice or receipt, please first check your spam folder and confirm that your email address is correct in your account settings. If the issue persists, contact our support team at support@fitly.live for further assistance.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
        title: const Text(
          'FAQ / Help',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return ExpansionTile(
            title: Text(
              faq['question']!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  faq['answer']!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
