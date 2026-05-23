import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalAgreementPage extends StatelessWidget {
  const LegalAgreementPage({super.key});

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  static const String _policyText = '''
FITLY LEGAL AGREEMENT
Last updated: 23 May 2026

By creating an account or using Fitly, you confirm that you have read, understood, and agree to this Legal Agreement, including the Terms of Service, Privacy Policy, Safety Disclaimer, User Agreement, Trainer Agreement, Code of Conduct, Refund Policy, and Data Breach Response Policy.

If you do not agree, you must not use Fitly.

============================
TERMS OF SERVICE
============================

1. About Fitly

Fitly is an online marketplace platform that helps customers discover and connect with independent personal trainers.

Fitly does not employ personal trainers. Fitly does not provide personal training, medical advice, physiotherapy, dietetic services, nutrition advice, rehabilitation services, or health advice.

All training services, communications, bookings, payments, sessions, locations, and outcomes are arranged directly between the customer and the trainer unless Fitly expressly states otherwise.

2. Eligibility

You must be at least 18 years old to create an account or use Fitly.

By using Fitly, you confirm that:
• You are at least 18 years old.
• The information you provide is accurate and current.
• You will use Fitly only for lawful purposes.
• You are responsible for your own decisions when engaging with other users.

3. Fitly’s Role as a Marketplace

Fitly helps customers and trainers connect. Fitly is not a party to any training arrangement between a customer and trainer.

Fitly does not guarantee:
• The quality, safety, suitability, availability, or outcome of any training service.
• That a trainer will meet a customer’s expectations.
• That a customer will continue with, attend, or pay for sessions.
• That a trainer’s qualifications, insurance, experience, profile claims, or services are accurate, current, or suitable.
• That a training venue, gym, park, home, or other session location is safe or appropriate.

Users should make their own enquiries before engaging in any training arrangement.

4. Independent Trainers

Trainers listed on Fitly are independent service providers. They are not employees, agents, partners, representatives, contractors, or franchisees of Fitly.

Trainers are solely responsible for:
• Their behaviour and professional conduct.
• The information shown on their profile.
• Their qualifications, registrations, certifications, insurance, experience, and claims.
• Their training programs, session plans, advice, instructions, and services.
• Assessing whether a venue or session location is safe and suitable.
• Complying with all applicable laws, standards, and professional obligations.
• Managing payment arrangements directly with customers where payment is not processed by Fitly.

Fitly may request evidence of qualifications or insurance, but any review by Fitly is limited. Fitly does not guarantee the authenticity, validity, completeness, or ongoing status of any trainer document.

5. Customer Responsibilities

Customers are responsible for:
• Choosing whether a trainer is suitable for them.
• Checking trainer qualifications, insurance, experience, reviews, location, pricing, and services before proceeding.
• Disclosing relevant health, injury, fitness, or safety information directly to the trainer where appropriate.
• Seeking medical advice before starting exercise if they have health concerns, injuries, medical conditions, or are unsure whether exercise is safe for them.
• Attending sessions safely and respectfully.
• Resolving payment, cancellation, rescheduling, and service disputes directly with the trainer unless Fitly expressly states otherwise.

6. Health and Fitness Disclaimer

Fitness activity involves risk. This may include injury, illness, aggravation of existing conditions, property damage, or other loss.

Fitly does not provide medical, health, physiotherapy, rehabilitation, nutrition, diet, or fitness advice. Any training advice or exercise instruction is provided by the trainer directly, not by Fitly.

You are responsible for deciding whether a trainer, exercise program, session, venue, or activity is suitable for your body, health, injuries, fitness level, goals, and personal circumstances.

If you have any medical condition, injury, disability, concern, or uncertainty, you should seek advice from a qualified healthcare professional before starting or continuing a fitness program.

To the maximum extent permitted by law, Fitly is not responsible for injuries, health issues, losses, or damages arising from trainer-client interactions, exercise activities, venues, advice, programs, or sessions.

7. Current Pricing and Future Paid Features

Fitly is currently free to use for customers and trainers unless stated otherwise in the app.

Fitly may introduce paid plans, subscriptions, promoted listings, booking features, advertising features, or other paid services in the future.

If paid features are introduced, pricing, renewal terms, cancellation terms, and any important conditions will be presented before purchase where required.

8. Payments Between Customers and Trainers

Unless Fitly expressly provides an in-app payment system for a specific transaction, payments for personal training services are arranged directly between customers and trainers.

Fitly is not responsible for:
• Enforcing payment agreements between customers and trainers.
• Refunds for payments made directly to trainers.
• Missed sessions, cancellations, no-shows, late payments, or pricing disputes.
• A trainer’s failure to provide services after payment.
• A customer’s failure to pay a trainer.

Users should keep their own records of payment arrangements, invoices, receipts, cancellations, and session terms.

9. Refunds and Australian Consumer Law

Nothing in this Agreement excludes, restricts, or modifies any consumer guarantee, right, remedy, or protection that cannot be excluded under Australian Consumer Law or other applicable law.

If Fitly introduces paid features in the future, fees may be generally non-refundable except where required by Australian Consumer Law or another applicable law, or where Fitly decides to provide a refund at its discretion.

10. User Conduct

You must not:
• Provide false, misleading, deceptive, or incomplete information.
• Harass, threaten, abuse, discriminate against, or intimidate another user.
• Use Fitly for unlawful, unsafe, misleading, or harmful activity.
• Upload offensive, defamatory, explicit, fraudulent, or infringing content.
• Create fake accounts, fake reviews, duplicate profiles, or misleading listings.
• Attempt to damage, disrupt, reverse engineer, scrape, copy, or misuse Fitly.
• Misrepresent your identity, qualifications, insurance, experience, or services.
• Use Fitly to promote scams, unsafe services, or unlawful activity.

11. Reviews, Profiles, and User Content

Users may upload or submit profile information, images, messages, reviews, ratings, and other content.

By submitting content to Fitly, you grant Fitly a non-exclusive, royalty-free, worldwide licence to use, display, store, reproduce, moderate, and publish that content for the purpose of operating, improving, and promoting the platform.

You are responsible for ensuring your content is accurate, lawful, respectful, and does not infringe another person’s rights.

Fitly may remove, hide, edit, restrict, or moderate content at its discretion.

12. Reports, Safety Concerns, and Account Action

Fitly may review, suspend, hide, restrict, or remove any account, profile, message, review, listing, or content where Fitly believes there may be:
• A breach of this Agreement.
• Misleading information.
• Safety concerns.
• Harassment, abuse, or inappropriate behaviour.
• Fake reviews or fake accounts.
• Complaints from users.
• Conduct that may harm users, Fitly, or the reputation of the platform.

Fitly is not required to investigate every complaint or resolve every dispute, but may take action where it considers appropriate.

13. No Guarantee of Results

Fitly does not guarantee fitness results, weight loss, muscle gain, improved health, customer leads, trainer bookings, income, business growth, or any specific outcome from using the platform.

14. Limitation of Liability

To the maximum extent permitted by law, Fitly is not liable for:
• Trainer or customer behaviour.
• Injuries, illness, accidents, or health consequences.
• Training outcomes or dissatisfaction with services.
• Venue safety or suitability.
• Payment disputes between users.
• Loss of income, opportunity, profits, data, goodwill, or reputation.
• Indirect, incidental, special, or consequential loss.
• User-generated content, reviews, advertisements, or profile claims.
• Unauthorised access to accounts or data, except where liability cannot be excluded by law.
• Interruptions, errors, bugs, downtime, or technical issues.

15. Indemnity

To the maximum extent permitted by law, you agree to indemnify Fitly, its owners, officers, employees, contractors, and service providers against claims, losses, damages, liabilities, costs, or expenses arising from:
• Your use of Fitly.
• Your breach of this Agreement.
• Your conduct with another user.
• Your services, advice, sessions, or training activity.
• Your uploaded content, profile claims, reviews, or messages.
• Your breach of any law or third-party right.

16. Termination

Fitly may suspend, restrict, or terminate your account at any time if you breach this Agreement, create risk for users, provide misleading information, misuse the platform, or engage in conduct Fitly considers harmful.

You may stop using Fitly at any time.

17. Changes to Fitly or These Terms

Fitly may update the app, features, pricing, policies, or this Agreement from time to time.

Continued use of Fitly after changes are made means you accept the updated terms.

18. Governing Law

This Agreement is governed by the laws of New South Wales, Australia, unless another Australian law applies.

============================
PRIVACY POLICY
============================

1. Overview

Fitly respects your privacy and aims to handle personal information responsibly in accordance with applicable Australian privacy laws.

This Privacy Policy explains what information Fitly may collect, why it is used, who it may be shared with, and how users can contact Fitly about privacy matters.

2. Information We May Collect

Fitly may collect:
• Name, email address, phone number, date of birth, and account details.
• Profile information such as bio, location/suburb, services, goals, preferences, photos, specialties, qualifications, insurance details, and availability.
• Messages, reports, reviews, ratings, support requests, and communications.
• Device information, app version, crash logs, diagnostic data, and usage information.
• Authentication information from sign-in providers such as Google or Apple.
• Payment or subscription-related information if paid features are introduced.
• Any other information you choose to provide through the app.

3. How We Use Information

Fitly may use information to:
• Create and manage accounts.
• Display customer and trainer profiles.
• Help customers and trainers connect.
• Provide messaging, support, safety, reporting, and moderation features.
• Improve app functionality, reliability, design, and performance.
• Send service-related notifications.
• Detect misuse, fake accounts, fraud, safety concerns, or policy breaches.
• Maintain records for legal, security, compliance, and dispute purposes.
• Comply with legal obligations.

4. Third-Party Services

Fitly may use third-party services to operate the platform, including:
• Firebase Authentication.
• Cloud Firestore.
• Firebase Storage.
• Firebase Cloud Messaging.
• Firebase Crashlytics.
• Firebase Remote Config.
• Google Sign-In.
• Apple Sign-In.
• Google Play services.
• Apple App Store services.
• Stripe or other payment processors if paid features are introduced.
• Email, hosting, analytics, support, or security providers where needed.

These providers may process information according to their own privacy and security practices.

5. Sharing of Information

Fitly may share information:
• Between customers and trainers where needed for platform functionality.
• With service providers that help operate, secure, host, analyse, or support Fitly.
• With payment processors if paid features are introduced.
• With legal, regulatory, law enforcement, or safety authorities where required or appropriate.
• With professional advisers where needed.
• Where necessary to investigate misuse, safety concerns, disputes, or legal claims.
• With your consent or at your direction.

Fitly does not sell users’ personal information to advertisers.

6. Public Profile Information

Trainer profile information may be visible to customers and other users. This may include name, profile photo, suburb or service area, bio, specialties, pricing or service details, qualifications, insurance indicators, images, reviews, and other information added by the trainer.

Users should avoid uploading information they do not want visible to others.

7. Data Security

Fitly uses reasonable technical and organisational measures to protect personal information.

However, no app, database, internet transmission, or storage system can be guaranteed to be completely secure. Users are responsible for keeping their login details safe.

8. Data Retention

Fitly may retain personal information while your account is active and for as long as reasonably needed for legal, security, backup, dispute, compliance, fraud prevention, and business purposes.

Some information may be retained after account deletion where required or permitted by law.

9. Access, Correction, and Deletion

You may request access to, correction of, or deletion of your personal information by contacting:

support@fitly.live

Some deletion requests may be limited where Fitly needs to retain information for legal, security, dispute, or compliance reasons.

10. Notifications

Fitly may send service-related notifications, including account, message, update, safety, or support notifications.

You may control notification permissions through your device settings.

11. Children

Fitly is intended for users aged 18 and over. Fitly is not intended for children.

12. Privacy Complaints

If you have a privacy question or complaint, contact:

support@fitly.live

Fitly will review privacy concerns and respond where appropriate.

============================
TRAINER AGREEMENT
============================

This section applies to trainers.

By creating a trainer profile, you agree that:

• You are responsible for all services you provide.
• You will provide accurate and current profile information.
• You will not exaggerate or misrepresent your qualifications, experience, insurance, availability, services, pricing, or results.
• You will maintain any qualifications, licences, registrations, insurance, or approvals required by law or professional standards.
• You will conduct sessions safely, professionally, respectfully, and lawfully.
• You will assess whether a customer, exercise, program, and venue is appropriate.
• You will not provide medical, physiotherapy, rehabilitation, dietetic, or other regulated advice unless properly qualified and legally permitted to do so.
• You will manage customer payments, cancellations, refunds, and disputes professionally where payments are arranged directly with customers.
• You will not harass, pressure, mislead, exploit, or abuse customers.
• You will not upload fake reviews, fake photos, false claims, or misleading profile content.
• You will comply with all applicable laws, including Australian Consumer Law where relevant.

Fitly may hide, suspend, restrict, or remove trainer profiles where Fitly identifies complaints, safety concerns, misleading information, non-compliance, or conduct Fitly considers inappropriate.

============================
CUSTOMER AGREEMENT
============================

This section applies to customers.

By using Fitly as a customer, you agree that:

• You are responsible for choosing whether a trainer is suitable for you.
• You should check trainer information before engaging a trainer.
• You should seek medical advice before starting exercise if you have health concerns or injuries.
• You are responsible for communicating honestly with trainers about relevant health, injury, safety, scheduling, and payment matters.
• You will treat trainers respectfully.
• You will not make false complaints, fake reviews, or abusive comments.
• You will manage direct payment arrangements with trainers responsibly.

============================
CODE OF CONDUCT
============================

All users must:

• Treat others respectfully.
• Communicate honestly and professionally.
• Avoid harassment, discrimination, threats, abuse, sexual misconduct, intimidation, or unsafe behaviour.
• Avoid false, misleading, defamatory, offensive, or harmful content.
• Respect privacy and confidentiality.
• Report serious safety concerns or inappropriate behaviour to Fitly.

Fitly may take action against accounts that breach this Code of Conduct.

============================
DISPUTE RESOLUTION
============================

Fitly encourages users to resolve disputes directly and respectfully.

If needed, users may contact:

support@fitly.live

Fitly may review information and take platform-related action at its discretion, such as removing content, restricting accounts, or suspending profiles.

Fitly is not required to mediate, decide, or resolve disputes between customers and trainers.

Users may contact external bodies such as Fair Trading, the ACCC, police, or legal advisers where appropriate.

============================
REFUND POLICY
============================

Fitly is currently free unless stated otherwise in the app.

If paid features are introduced in the future:

• Payment terms will be displayed before purchase where required.
• Fees may be generally non-refundable except where required by Australian Consumer Law or another applicable law.
• Refund requests may be reviewed at Fitly’s discretion.
• Approved refunds will usually be returned to the original payment method where possible.
• Payments made directly between customers and trainers are not Fitly payments and must be resolved directly between those users.

Nothing in this Refund Policy limits any non-excludable rights under Australian Consumer Law.

============================
DATA BREACH RESPONSE
============================

If Fitly becomes aware of a suspected or confirmed data breach involving personal information, Fitly may:

• Investigate the incident.
• Take steps to contain and reduce harm.
• Review what information may have been affected.
• Notify affected users where appropriate or required.
• Notify relevant authorities where required by law.
• Take reasonable steps to reduce the risk of similar incidents.

Users should promptly contact support@fitly.live if they believe their account or personal information has been compromised.

============================
NDIS EXCLUSION
============================

Fitly does not provide or facilitate NDIS services.

Fitly is not an NDIS provider marketplace and is not intended for arranging supports under the National Disability Insurance Scheme.

Users seeking NDIS-related services should use appropriate NDIS-compliant channels and providers.

============================
CONTACT
============================

For support, legal, privacy, safety, or account questions, contact:

support@fitly.live

By tapping “I Agree” or continuing to use Fitly, you acknowledge that you have read, understood, and agree to this Legal Agreement.
''';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: _bgTop,
          foregroundColor: _textMain,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: _textMain),
          title: const Text(
            'Legal Agreement',
            style: TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        body: Stack(
          children: [
            const _LegalBackground(),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIntroCard(),
                    const SizedBox(height: 14),
                    _buildPolicyCard(),
                    const SizedBox(height: 18),
                    _buildAgreeButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please review before continuing',
            style: TextStyle(
              color: _textMain,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This explains how Fitly works, your responsibilities, privacy handling, safety limits, and trainer conduct expectations.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const SelectableText(
        _policyText,
        style: TextStyle(
          color: _textMain,
          fontSize: 13.5,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAgreeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gold, _goldDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.20),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF121212),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'I Agree',
            style: TextStyle(
              color: Color(0xFF121212),
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalBackground extends StatelessWidget {
  const _LegalBackground();

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _gold = Color(0xFFE7B95C);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -120,
          child: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -140,
          child: Container(
            height: 340,
            width: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.06),
            ),
          ),
        ),
      ],
    );
  }
}