import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  // Removed the "**Terms of Service**" line from _termsText
  // because we are showing a large, bold heading above the text.
  final String _termsText = '''
1. **Introduction**  
Welcome to Fitly ("the Platform"). These Terms of Service ("Terms") govern your access to and use of the Platform provided by Fitly ("we," "us," or "our"). By accessing or using the Platform, you agree to these Terms. If you do not agree, do not use the Platform.

2. **About the Platform**  
The Platform is an online marketplace that connects personal trainers ("Trainers") with clients ("Clients"). We facilitate connections and transactions but do not employ Trainers or guarantee the quality of services provided.

3. **Eligibility**  
To use the Platform, you must be at least 18 years old and capable of entering into a legally binding agreement. By using the Platform, you represent and warrant that you meet these requirements.

4. **User Responsibilities**  
**Trainers:**  
- Provide accurate and complete information, including valid certifications and insurance.  
- Deliver services in a professional and timely manner.  
- Comply with all applicable laws and industry standards.  

**Clients:**  
- Provide accurate booking details and make payments promptly.  
- Communicate respectfully with Trainers.  
- Use the Platform solely for lawful purposes.

5. **Trainer Code of Conduct**  
Trainers listed on the Platform are encouraged to:  
- Respect the rights and privacy of all individuals.  
- Provide services with care, skill, and safety.  
- Avoid conflicts of interest and act with honesty and transparency.  
- Respond to client concerns and feedback professionally.  

*Note: These guidelines are provided to promote professionalism but do not create enforceable obligations for the Platform. Trainers remain solely responsible for adhering to these principles.*

6. **Platform Responsibilities**  
We are responsible for:  
- Providing a secure environment for Trainers and Clients to connect.  
- Processing payments securely via third-party payment gateways.  
- Offering support for disputes in accordance with applicable law.  

We are not responsible for:  
- The quality or outcome of services provided by Trainers.  
- Verifying the authenticity of Trainer certifications or insurance beyond sighting them.  
- Losses resulting from Trainer or Client conduct.  
- Injuries or accidents that occur during Trainer-Client sessions.  
- The location, safety, or suitability of gym or session venues.  
- Any disputes arising from payments made directly between Clients and Trainers.  
- Ensuring that Clients fulfill their payment obligations to Trainers.

7. **Payments and Fees**  
**Trainers:**  
- Trainers pay a subscription fee of \$30/month to be listed on the Platform.  
- Subscription fees are non-refundable, including if Trainers choose to terminate their subscription mid-month or fail to utilize the Platform.  

**Clients:**  
- Clients make payments for services directly to Trainers. The Platform is not responsible for payment disputes or issues between Clients and Trainers.  

All subscription fees are processed securely via Stripe. Fees are non-refundable except as required by law.

8. **Prohibited Conduct**  
You agree not to:  
- Circumvent the Platform’s fee structure by transacting outside the Platform.  
- Provide false, misleading, or incomplete information.  
- Engage in any unlawful or harmful activity using the Platform.  
- Open multiple accounts or create multiple listings under different accounts without prior approval from the Platform.

9. **Reviews and Ratings; User-Generated Content**  
Clients may leave reviews and ratings for Trainers. By submitting a review, you agree that it reflects your honest opinion. We reserve the right to moderate or remove reviews or any other user-generated content that violates these Terms or our community guidelines.

**User-Generated Content Ownership and Rights:**  
All content submitted by users remains your property; however, by posting content on the Platform, you grant us a non‑exclusive, royalty‑free, worldwide license to use, modify, distribute, and display such content. We reserve the right to moderate or remove any content that violates these Terms or is deemed inappropriate.

10. **Insurance and Liability**  
- Trainers are encouraged to maintain public liability and professional indemnity insurance to cover their activities. The Platform only verifies the sighting of insurance documents but does not validate their authenticity or ongoing validity.  
- If a Trainer has valid insurance, this will be indicated on their profile for Client visibility.  
- The Platform is not liable for any injuries, property damage, or other losses arising from Trainer-Client interactions, irrespective of whether the Trainer holds valid insurance.  
- Trainers are responsible for ensuring their services comply with all legal and professional requirements, including maintaining up‑to‑date insurance if applicable.  
- We are not responsible for the location, safety, or suitability of gym or session venues chosen by Trainers or Clients.

11. **Dispute Resolution**  
- We encourage Trainers and Clients to resolve disputes directly. If resolution is not possible, you may contact us at support@fitly.live.  
- While we may, at our discretion, provide mediation support, we are not responsible for resolving disputes. Any disputes will be subject to and resolved in accordance with applicable Australian laws.

12. **No Agency Relationship**  
No agency, partnership, joint venture, employee‑employer, or similar relationship is created by this Agreement. Trainers and Clients act independently, and the Platform has no authority to bind or represent any user. We specifically disclaim all liability for any loss or damage incurred by Trainers or Clients due to the performance or non‑performance of services.

13. **Termination**  
We may suspend or terminate your account at our discretion if you:  
- Breach these Terms.  
- Engage in fraudulent or harmful activity.  
- Fail to pay applicable fees.  

Trainers' listings may be removed instantly or within 24–48 hours upon termination of their subscription or account. Trainers are responsible for ensuring any active client arrangements are concluded before termination.

14. **Intellectual Property**  
All content on the Platform, including logos, designs, and software, is owned by us or licensed to us. You may not use, reproduce, or distribute our content without prior written consent.

15. **Privacy**  
Our handling of personal information is governed by our Privacy Policy, available at [Privacy Policy Link].  
Upon account termination, we may retain certain user data as required for compliance with legal obligations, dispute resolution, or enforcement of these Terms. Retained data will be securely stored and only used for these purposes.

16. **Limitation of Liability and Disclaimer of Warranties**  
To the extent permitted by law, we are not liable for:  
- Indirect, incidental, or consequential damages.  
- Losses arising from the conduct of Trainers or Clients.  
- Any unauthorized access to your data.  
- Injuries, property damage, or any incidents occurring during Trainer-Client sessions.  
- The safety, condition, or appropriateness of session venues.  
- Payment disputes between Clients and Trainers.  
- Ensuring Clients fulfill payment obligations to Trainers.  

The Platform is provided on an "as is" and "as available" basis without any warranties, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, or non‑infringement.

17. **Service Level and Support**  
We strive to provide a reliable and secure Platform. While we aim for a high level of uptime, we do not guarantee uninterrupted service and reserve the right to perform maintenance, which may result in temporary service interruptions. For technical support or assistance, please contact support@fitly.live. We will make reasonable efforts to respond to support inquiries in a timely manner.

18. **Changes to the Terms**  
We may update these Terms at any time. Changes will be effective upon posting on the Platform. For significant changes, we may notify you via email or through a prominent notice on the Platform. Continued use of the Platform constitutes acceptance of the updated Terms.

19. **Governing Law**  
These Terms are governed by the laws of the relevant states of Australia. Any disputes shall be resolved in accordance with the jurisdiction of the applicable state.

20. **Contact Us**  
For questions or support, contact us at support@fitly.live.

21. **Exclusion of NDIS Clients**  
The Platform does not facilitate services for NDIS clients or providers. Users requiring NDIS-related services should seek appropriate platforms or providers that meet regulatory compliance.

22. **Force Majeure**  
We are not responsible for any failure or delay in providing the Platform due to circumstances beyond our reasonable control, including but not limited to acts of God, government actions, internet service interruptions, or technical failures.

23. **Indemnification**  
You agree to indemnify and hold harmless Fitly, its affiliates, officers, and employees from any claims, losses, or damages, including legal fees, arising from your use of the Platform or violation of these Terms.

24. **Severability Clause**  
If any provision of these Terms is found to be invalid or unenforceable by a court of competent jurisdiction, the remaining provisions shall continue in full force and effect.

25. **No Waiver Clause**  
The failure of Fitly to enforce any right or provision of these Terms shall not be deemed a waiver of such right or provision in the future.

26. **User-Generated Content Ownership and Rights**  
All content submitted by users remains your property; however, by posting content on the Platform, you grant us a non‑exclusive, royalty‑free, worldwide license to use, modify, distribute, and display such content. We reserve the right to moderate or remove any content that violates these Terms or our community guidelines.

27. **Third-Party Payment Processing**  
We utilize Stripe for secure payment processing. Any issues related to payment processing shall be governed by Stripe’s terms and policies. We are not responsible for any failures or disputes arising from the third‑party payment services provided by Stripe.

28. **Integration Clause**  
These Terms constitute the entire agreement between you and Fitly regarding your use of the Platform and supersede all prior or contemporaneous communications, agreements, or understandings, whether written or oral.

By using the Platform, you acknowledge that you have read, understood, and agree to these Terms of Service.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: const Color.fromARGB(255, 255, 167, 38),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large, bold heading for "Terms of Service"
            const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // The rest of your terms in a selectable, scrollable text
            SelectableText(
              _termsText,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
