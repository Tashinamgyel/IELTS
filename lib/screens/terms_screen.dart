// lib/screens/terms_screen.dart
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '''
Welcome to IELTS Essay App

1. Acceptance of Terms
By accessing and using this app ("App"), you agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree with any part of these terms, you must not use our app.

2. Use License
You are granted a limited, non-exclusive, non-transferable license to use the App for your personal, non-commercial use only. You may not modify, reproduce, distribute, or create derivative works based on the App content without prior written permission.

3. User Account and Security
You are responsible for maintaining the security of your account and any activity under your account. Please notify us immediately if you suspect any unauthorized use of your account.

4. Content and Copyright
All content provided in the App—including text, images, and generated essays—is protected by copyright and intellectual property laws. You agree not to copy, modify, or distribute any content from the App without explicit permission.

5. Disclaimer of Warranties
The App is provided on an “as is” and “as available” basis. We do not guarantee that the App will be error-free or continuously available. Use of the App is at your own risk.

6. Limitation of Liability
Under no circumstances shall the App developers be liable for any direct, indirect, incidental, consequential, or exemplary damages arising from your use of the App or inability to access the App.

7. Modifications to Terms
We may update these Terms from time to time. We encourage you to review these Terms periodically. Your continued use of the App after any changes indicates your acceptance of the new Terms.

8. Governing Law
These Terms shall be governed by and interpreted in accordance with the laws of the jurisdiction in which the App operates, without regard to conflict of law principles.

If you have any questions about these Terms of Service, please contact our support team.

Last updated: April 2025
          ''',
          style: TextStyle(fontSize: 16.0, height: 1.5),
        ),
      ),
    );
  }
}
