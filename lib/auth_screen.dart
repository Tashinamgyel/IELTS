// lib/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/terms_screen.dart';

class AuthScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final VoidCallback onSignIn; // Callback when sign in succeeds

  const AuthScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onSignIn,
  });

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSigningIn = false;

  /// General Google sign in method.
  /// If [forceSelection] is true, clears any cached account first to force account selection.
  Future<User?> signInWithGoogle({bool forceSelection = false}) async {
    if (forceSelection) {
      // Force account selection by signing out from Google.
      await GoogleSignIn().signOut();
      // Optionally, you can also disconnect:
      // await GoogleSignIn().disconnect();
    }
    setState(() {
      _isSigningIn = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // Sign in aborted.
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sign in aborted')));
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      return userCredential.user;
    } catch (error) {
      debugPrint("Google sign in error: $error");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error signing in: $error')));
      return null;
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  Widget _buildGoogleButton(String text, {bool forceAccountSelection = false}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        elevation: 4,
      ),
      icon: Image.asset(
        'assets/google_logo.png', // Verify this asset is declared in pubspec.yaml
        height: 24.0,
        width: 24.0,
      ),
      label: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      onPressed: _isSigningIn
          ? null
          : () async {
        // For registration force a new account selection.
        User? user = await signInWithGoogle(forceSelection: forceAccountSelection);
        if (user != null) {
          widget.onSignIn();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modern design: full-screen gradient and centered card.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00A8E8), Color(0xFF007EA7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App logo placeholder (replace with your own asset if available)
                    Image.asset('assets/logo.png', width: 150,),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Welcome to IELTS Essay App',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'Easily generate high-quality IELTS essays with one click',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32.0),
                    // Login uses the cached account
                    _buildGoogleButton("Login with Google"),
                    const SizedBox(height: 16.0),
                    // Registration forces account selection, so user can choose a different account.
                    _buildGoogleButton("Register with Google", forceAccountSelection: true),
                    if (_isSigningIn) const SizedBox(height: 16.0),
                    if (_isSigningIn) const CircularProgressIndicator(),
                    const SizedBox(height: 16.0),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TermsScreen()),
                        );
                      },
                      child: const Text(
                        'Terms of Service | Privacy Policy',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
