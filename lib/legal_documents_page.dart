import 'package:flutter/material.dart';

class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  // Helper widget to build an expansion tile for each legal section.
  Widget _buildExpansionTile(String title, String content) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Multi-line strings for each policy.
    const String refundPolicy = '''
1. Overview
Fitly ("the Platform") aims to provide a fair and transparent refund process for all subscription payments made by trainers. By using the Platform, you agree to the terms outlined in this Refund Policy.
2. Subscription Fees
• Subscription fees paid by trainers are non-refundable once the subscription period begins.
• This includes situations where a trainer terminates their subscription mid-month or fails to utilize the Platform’s services during the subscription period.
3. Exceptional Circumstances
Refunds may be considered in exceptional circumstances, including but not limited to:
• Duplicate payments made in error.
• Platform functionality issues that prevent trainers from accessing or using the Platform’s core services for an extended period (verified by our support team).
• Any other circumstances deemed reasonable by Fitly’s management at their sole discretion.
4. Refund Request Process
To request a refund:
• Contact our support team at support@fitly.live within 14 days of the payment date.
• Provide detailed information, including the reason for the refund request and proof of payment (e.g., receipt or transaction ID).
• Our team will review your request and notify you of the outcome within 7 business days.
5. Processing Refunds
• Approved refunds will be processed to the original payment method within 10 business days.
• Refunds may take additional time to appear in your account depending on your financial institution’s policies.
6. Non-Refundable Situations
Refunds will not be provided for:
• Change of mind after the subscription period begins.
• Failure to cancel the subscription before the next billing cycle.
• Non-usage of the Platform’s services during the subscription period.
7. Changes to This Refund Policy
Fitly reserves the right to modify this Refund Policy at any time. Changes will be posted on the Platform, and continued use constitutes acceptance of the updated policy.
8. Contact Us
For any questions or concerns about this Refund Policy, please contact us at support@fitly.live.
By using the Platform, you acknowledge that you have read and understood this Refund Policy and agree to its terms.
''';

    const String cookiePolicy = '''
1. Overview
Fitly ("the Platform") operates in compliance with applicable laws, including the Australian Privacy Act 1988. We use cookies and similar tracking technologies to enhance your experience, analyze usage, and provide personalized services. By accessing or using the Platform, you consent to the use of cookies as outlined in this Cookie Policy.
2. What Are Cookies?
Cookies are small text files stored on your device when you visit a website. They help improve the Platform by remembering your preferences and tracking interactions.
3. Types of Cookies We Use
• Essential Cookies: Necessary for the operation of the Platform (e.g., secure logins and navigation).
• Performance Cookies: Collect anonymous data to understand usage and improve functionality.
• Functional Cookies: Remember your preferences (e.g., language or region) for a tailored experience.
• Analytics and Tracking Cookies: Monitor usage and gather insights via third-party tools like Google Analytics.
4. How We Use Cookies
We use cookies to ensure proper functioning of the Platform, enhance user experience, analyze traffic, and deliver personalized services.
5. Third-Party Cookies
We may allow third-party service providers to place cookies for analytics and advertising. These providers are subject to their own privacy policies.
6. Managing Cookies
You can manage or disable cookies through your browser settings, although this may affect the Platform’s functionality.
7. Changes to This Cookie Policy
This Cookie Policy may be updated at any time without prior notice. Continued use of the Platform constitutes acceptance of the updated policy.
8. Contact Us
For any questions or concerns, please contact support@fitly.live.
By using the Platform, you acknowledge that you have read and understood this Cookie Policy and agree to our use of cookies.
''';

    const String userAgreement = '''
1. Introduction
This User Agreement ("Agreement") governs your use of the Fitly platform ("Platform"), which connects personal trainers ("Trainers") with clients ("Clients"). By accessing or using the Platform, you agree to comply with this Agreement. If you do not agree, you must not use the Platform.
2. Account Registration and Responsibilities
• Users must be at least 18 years old to register an account.
• Provide accurate and complete information during registration and update it as needed.
• You are responsible for maintaining the confidentiality of your account credentials.
3. Services Provided
• The Platform facilitates connections but does not employ Trainers or guarantee service quality.
• All agreements are made directly between Trainers and Clients.
4. Payments
• Trainers pay a subscription fee to be listed; Clients pay Trainers directly.
• Non-payment of subscription fees may result in suspension or removal of listings.
• The Platform is not responsible for payment disputes.
5. User Conduct
• Users must not provide false information or engage in unlawful or abusive behavior.
6. Content and Reviews
• Reviews are posted honestly; false or defamatory content may be removed.
7. Dispute Resolution
• Users should attempt direct resolution; the Platform may mediate at its discretion.
8. Limitation of Liability
• The Platform is not liable for any damages arising from interactions or inaccuracies.
9. Termination
• The Platform reserves the right to terminate accounts for breaches.
10. Privacy
• The collection and use of your information are governed by our Privacy Policy.
11. Changes to This Agreement
• The Platform may update this Agreement at any time; changes are effective upon posting.
12. Governing Law
• This Agreement is governed by the laws of Australia.
13. Contact Us
For questions, contact support@fitly.live.
By using the Platform, you acknowledge that you have read and agree to this Agreement.
''';

    const String trainerAgreement = '''
1. Introduction
This Trainer Agreement ("Agreement") governs the terms for personal trainers ("Trainers") using the Fitly platform ("Platform"). By registering as a Trainer, you agree to these terms.
2. Trainer Responsibilities
• Provide services with professionalism and maintain valid certifications, licenses, and insurance.
• Ensure Client safety during sessions and comply with applicable laws.
3. Certification and Insurance
• Provide accurate and up-to-date documentation; failure to do so may result in suspension.
4. Subscription and Fees
• Trainers must pay a subscription fee to be listed; fees are non-refundable.
5. Use of the Platform
• Listings are exclusive to Fitly and may not be duplicated without consent.
6. Client Interactions
• Communicate respectfully and address Client concerns promptly.
7. Reviews and Ratings
• Reviews are subject to moderation; falsification is prohibited.
8. Limitation of Liability
• The Platform is not liable for interactions or dissatisfaction with training outcomes.
9. Termination
• Accounts may be suspended or terminated for breaches or non-payment.
10. Privacy
• Personal information is governed by our Privacy Policy.
11. Changes to This Agreement
• The Platform may update this Agreement at any time.
12. Governing Law
• Governed by the laws of Australia.
13. Contact Us
For questions, contact support@fitly.live.
By registering as a Trainer, you acknowledge that you have read and agree to these terms.
''';

    const String disputeResolutionPolicy = '''
1. Purpose
This policy outlines procedures for resolving disputes between Trainers and Clients on the Fitly platform ("Platform"). The Platform is committed to a fair and transparent process.
2. Scope
Applies to disputes arising from the use of the Platform.
3. General Principles
• Trainers and Clients should resolve disputes directly and professionally.
• The Platform may offer limited mediation, but is not obligated to resolve disputes.
4. Dispute Resolution Process
Step 1: Direct Resolution – Communicate directly and document communications.
Step 2: Platform Support – Contact support@fitly.live with detailed dispute information.
Step 3: External Resolution – If unresolved, contact external bodies like Fair Trading or ACCC.
5. Limitations
The Platform does not guarantee dispute resolution and is not liable for payment disputes.
6. Review and Appeals
Users may request a review by contacting support@fitly.live.
7. Consequences
The Platform may suspend or terminate accounts involved in unresolved disputes.
8. Changes to This Policy
This policy may be updated at any time; continued use constitutes acceptance.
9. Contact Us
For questions, contact support@fitly.live.
''';

    const String dataBreachResponsePolicy = '''
1. Purpose
This policy outlines the steps Fitly ("the Platform") will take to respond to a data breach, minimize its impact, and comply with applicable laws.
2. Scope
Applies to all suspected or confirmed data breaches involving personal information.
3. What is a Data Breach?
Occurs when personal information is accessed, disclosed, or lost without authorization.
4. Roles and Responsibilities
• The Platform implements security measures and appoints a Data Protection Officer (DPO).
• Staff are responsible for promptly reporting breaches.
5. Breach Response Process
Step 1: Identify and Contain – Immediately assess and contain the breach.
Step 2: Assess – Determine the nature and potential harm of the breach.
Step 3: Notify – If required, notify affected parties and authorities.
Step 4: Investigate and Remediate – Identify the cause and implement measures to prevent future breaches.
6. Record-Keeping
Maintain detailed records of breaches and actions taken.
7. Regular Review
This policy is reviewed regularly and updated as needed.
8. Contact Us
For questions or to report a breach, contact support@fitly.live.
''';

    const String codeOfConduct = '''
1. Purpose
Outlines expected behavior for all users of the Fitly platform to foster a professional, respectful, and safe environment.
2. Scope
Applies to all interactions on the Platform.
3. General Guidelines
• Treat all users with respect, professionalism, and courtesy.
• Avoid harassment, discrimination, or abusive behavior.
4. Trainer-Specific Responsibilities
• Provide services with care and maintain up-to-date certifications.
• Clearly communicate session details and ensure Client safety.
5. Client-Specific Responsibilities
• Attend sessions on time and treat Trainers respectfully.
• Make payments as agreed.
6. Prohibited Behaviors
• Providing false information or engaging in unlawful activities.
• Posting defamatory or offensive content.
7. Reviews and Feedback
• Post honest reviews based on genuine experiences.
• Avoid manipulating ratings or posting fabricated feedback.
8. Safety and Professionalism
• Both Trainers and Clients must report unsafe behavior.
9. Breach of Code
Violations may result in warnings, suspension, or termination.
10. Changes to This Code
The Platform may update this Code at any time.
11. Contact Us
For questions, contact support@fitly.live.
''';

    const String marketingAndAdvertisingPolicy = '''
1. Purpose
Outlines guidelines for marketing and promotional activities on the Fitly platform to ensure professionalism and compliance with applicable laws.
2. Scope
Applies to all marketing and advertising content on the Platform.
3. General Guidelines
• Advertisements must be truthful, accurate, and substantiated.
• They must comply with all applicable laws, including the Australian Consumer Law.
4. Prohibited Practices
• False, deceptive, or exaggerated claims.
• Discriminatory, offensive, or unauthorized promotional content.
5. Trainer Responsibilities
• Accurately represent services, qualifications, and availability.
• Clearly state terms and conditions for any special offers.
6. Use of Platform Features
• Trainers may use their profiles and listings for advertising if content adheres to this policy.
7. Review and Approval
• The Platform reserves the right to review and remove non-compliant advertisements.
8. Liability Disclaimer
• The Platform is not responsible for user-generated advertising content.
9. Changes to This Policy
This policy may be updated at any time; continued use constitutes acceptance.
10. Contact Us
For questions or concerns, please contact support@fitly.live.
''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Documents'),
        backgroundColor: const Color(0xFFFFA726),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Legal Documents',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 32, thickness: 2),
          _buildExpansionTile('Refund Policy', refundPolicy),
          _buildExpansionTile('Cookie Policy', cookiePolicy),
          _buildExpansionTile('User Agreement', userAgreement),
          _buildExpansionTile('Trainer Agreement', trainerAgreement),
          _buildExpansionTile(
              'Dispute Resolution Policy', disputeResolutionPolicy),
          _buildExpansionTile(
              'Data Breach Response Policy', dataBreachResponsePolicy),
          _buildExpansionTile('Code of Conduct', codeOfConduct),
          _buildExpansionTile('Marketing and Advertising Policy',
              marketingAndAdvertisingPolicy),
        ],
      ),
    );
  }
}
